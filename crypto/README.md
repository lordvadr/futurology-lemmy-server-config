## Generate keys

** RSA key **
```bash
openssl genrsa 4096 | gpg -ear yourkey@email.com > ssh_host_rsa_key.asc
```

** ECDSA key **
```bash
openssl ecparam -genkey -name prime256v1 | openssl ec 2>/dev/null | gpg -ear your@email.com > ssh_host_ecdsa_key.asc
```

** ED25519 key **
```bash
openssl genpkey -algorithm ed25519 | gpg -ear your@email.com > ssh_host_ed25519_key.asc
# MAYBE ssh-keygen required
```

## Generate the symmetric AES256 key that will be used to encrypt/decrypt the keys

```bash
dd if=/dev/random bs=256 count=1 iflag=fullblock 2>/dev/null | gpg -ear your@email.com > aeskey.asc
```

## Encrypt the AES256 key using the AWS KMS key

```bash
aws kms encrypt --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --plaintext "$(gpg -d aeskey.asc 2>/dev/null | base64 -w 0)" --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .CiphertextBlob > aeskey.enc
```
## Encrypt server keys to AWS KMS key

** RSA key **
```bash
gpg -d ssh_host_rsa_key.asc 2>/dev/null | openssl rsa 2>/dev/null -aes256 -passout file:<(aws kms decrypt --ciphertext-blob "$(cat aeskey.enc)" --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .Plaintext | base64 -d) > ssh_host_rsa_key.enc
```

** EDCSA key **
```bash
gpg -d ssh_host_ecdsa_key.asc 2>/dev/null | openssl ec 2>/dev/null -aes256 -passout file:<(aws kms decrypt --ciphertext-blob "$(cat aeskey.enc)" --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .Plaintext | base64 -d) > ssh_host_ecdsa_key.enc
```

** ED25519 key **
```bash
gpg -d ssh_host_ed25519_key.asc 2>/dev/null | openssl pkey -aes256 -passout file:<(aws kms decrypt --ciphertext-blob "$(cat aeskey.enc)" --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .Plaintext | base64 -d) > ssh_host_ed25519_key.enc
```

## Decrypt and install the keys

** RSA key **
```bash
openssl rsa -in ssh_host_rsa_key.enc -passin file:<(aws kms decrypt --ciphertext-blob "$(cat aeskey.enc)" --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .Plaintext | base64 -d) > /etc/ssh/ssh_host_rsa_key

openssl rsa -in /etc/ssh/ssh_host_rsa_key -pubout > /etc/ssh/ssh_host_rsa_key.pub
```

** EDCSA key **
```bash
openssl ec -in ssh_host_ecdsa_key.enc -passin file:<(aws kms decrypt --ciphertext-blob "$(cat aeskey.enc)" --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .Plaintext | base64 -d) 2>/dev/null >

openssl ec -in /etc/ssh/ssh_host_ecdsa_key -pubout 2>/dev/null > /etc/ssh/ssh_host_ecdsa_key.pub
```

** ED25519 key **
```bash
openssl pkey -in ssh_host_ed25519_key.enc -passin file:<(aws kms decrypt --ciphertext-blob "$(cat aeskey.enc)" --key-id 50cdd4ff-fa03-48bb-9768-cc3e1ecb9102 --encryption-algorithm RSAES_OAEP_SHA_256 | jq -r .Plaintext | base64 -d) > /etc/ssh/ssh_host_ed25519_key

openssl pkey -in /etc/ssh/ssh_host_ed25519_key -pubout > /etc/ssh/ssh_host_ed25519_key.pub
```

## Fix permissions on installed keys

```bash
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
```
