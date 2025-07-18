output "connect_access_node" {
  description = "SSH command for access-node"
  value       = <<-EOT
                Use the following command to log into access-node

                  ssh ubuntu@${aws_instance.access_node.public_ip}
                  

                EOT
}

output "address_access_node" {
  description = "Public IP of access-node"
  value       = aws_instance.access_node.public_ip
}

# We can use either of these IPs to connect to node ports
output "address_node01" {
  description = "Public IP of node01"
  value       = aws_instance.kubenode["node01"].public_ip
}

output "address_node02" {
  description = "Public IP of node02"
  value       = aws_instance.kubenode["node02"].public_ip
}