resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the private key to local .ssh directory so it can be used by SSH clients
resource "local_sensitive_file" "pem_file" {
  filename        = "${data.localos_folders.folders.ssh}/id_rsa" ## make it kube.pem 
  file_permission = "600"
  content         = tls_private_key.key_pair.private_key_pem
}

# Upload the public key of the key pair to AWS so it can be added to the instances
resource "aws_key_pair" "kube_kp" {
  key_name   = "kube_kp"
  public_key = trimspace(tls_private_key.key_pair.public_key_openssh)
}