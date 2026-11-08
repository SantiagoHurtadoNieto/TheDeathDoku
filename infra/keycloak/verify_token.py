#!/usr/bin/env python3
"""Verify a Keycloak access token signature and issuer using the realm JWKS."""

import argparse
import json
import sys
import jwt


def unverified_claims(token: str) -> dict:
    """Decode claims for diagnostics only. These values are untrusted until verification."""
    return jwt.decode(
        token,
        options={
            "verify_signature": False,
            "verify_exp": False,
            "verify_iss": False,
            "verify_aud": False,
        },
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("token", nargs="?", help=argparse.SUPPRESS)
    parser.add_argument(
        "--token-stdin",
        action="store_true",
        help="read the token from stdin so it is not included in process arguments",
    )
    parser.add_argument("--issuer", default="http://localhost:8180/realms/hopedoku")
    parser.add_argument(
        "--jwks-url",
        default="http://localhost:8180/realms/hopedoku/protocol/openid-connect/certs",
    )
    args = parser.parse_args()

    if args.token_stdin:
        token = sys.stdin.read().strip()
    else:
        token = args.token
    if not token:
        parser.error("provide a JWT or use --token-stdin")

    try:
        diagnostic = unverified_claims(token)
    except Exception as exc:
        print(f"UNVERIFIED_DECODE_ERROR: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    selected = (
        "iss",
        "sub",
        "azp",
        "typ",
        "scope",
        "exp",
        "preferred_username",
        "realm_access",
    )
    print(
        json.dumps(
            {
                "unverified_claim_names": sorted(diagnostic),
                "unverified_claims": {name: diagnostic.get(name) for name in selected},
            },
            indent=2,
        )
    )

    try:
        signing_key = jwt.PyJWKClient(args.jwks_url).get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            issuer=args.issuer,
            options={"require": ["iss", "sub", "exp"]},
        )
    except Exception as exc:
        print(f"INVALID: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1

    roles = claims.get("realm_access", {}).get("roles", [])
    safe = {
        "iss": claims.get("iss"),
        "sub": claims.get("sub"),
        "exp": claims.get("exp"),
        "preferred_username": claims.get("preferred_username"),
        "realm_access.roles": roles,
        "signature_valid": True,
    }
    print(json.dumps(safe, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
