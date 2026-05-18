# SoloDrop TLS certificates

Production mode expects:

- `cert.pem`
- `key.pem`

Set `https_enabled` to `true` in `config.json` only after placing a certificate and private key here. Development mode can run over HTTP, but iPhone production pairing/sync should use HTTPS/WSS.
