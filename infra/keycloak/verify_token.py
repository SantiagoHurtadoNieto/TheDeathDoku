#!/usr/bin/env python3
"""Verify a Keycloak access token signature and issuer using the realm JWKS."""

import argparse
import json
import sys
import jwt


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("token", help="JWT access token")
    parser.add_argument("--issuer", default="http://localhost:8180/realms/hopedoku")
    parser.add_argument(
        "--jwks-url",
        default="http://localhost:8180/realms/hopedoku/protocol/openid-connect/certs",
    )
    args = parser.parse_args()

    try:
        signing_key = jwt.PyJWKClient(args.jwks_url).get_signing_key_from_jwt(args.token)
        claims = jwt.decode(
            args.token,
            signing_key.key,
            algorithms=["RS256"],
            issuer=args.issuer,
            options={"require": ["iss", "exp"]},
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
