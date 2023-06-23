## Generate a random key passphrase

```bash
dd if=/dev/random bs=512 count=1 iflag=fullblock 2>/dev/null | tr -d '\000' | head -c 256 | gpg -ear lordvadr@futurology.social -o passphrase.asc
```

## Encrypt the AES256 key using the AWS KMS key

```bash
aws kms encrypt --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --plaintext "$(gpg -d passphrase.asc 2>/dev/null | base64 -w 0)" --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .CiphertextBlob > passphrase.enc
```
## Generate keys

** RSA key **
```bash
ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key -C root@futurology.social -N "$(gpg -d passphrase.asc 2>/dev/null)"
```

** ECDSA key **
```bash
ssh-keygen -t ecdsa -b 521 -f ssh_host_ecdsa_key -C root@futurology.social -N "$(gpg -d passphrase.asc 2>/dev/null)"
```

** ED25519 key **
```bash
ssh-keygen -t ed25519 -f ssh_host_ed25519_key -C root@futurology.social -N "$(gpg -d passphrase.asc 2>/dev/null)"
```
