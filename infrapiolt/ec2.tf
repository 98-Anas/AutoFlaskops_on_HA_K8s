resource "aws_network_interface" "kubenode" {
  for_each        = { for idx, inst in local.instances : inst => idx }
  subnet_id       = data.aws_subnets.public.ids[each.value % 3]
  security_groups = [aws_security_group.egress_all.id]
  tags = {
    Name = local.instances[each.value]
  }
}

resource "aws_instance" "kubenode" {
  for_each      = toset(local.instances)
  ami           = data.aws_ami.ubuntu.image_id
  key_name      = aws_key_pair.kube_kp.key_name
  instance_type = "t3.medium"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.kubenode[each.value].id
  }
  tags = merge( 
    {
    "Name" = each.value
    "Role" = local.instance_roles[each.value]
    },
    var.common_tags
  )
  user_data = <<-EOT
              #!/usr/bin/env bash
              hostnamectl set-hostname ${each.value}
              cat <<EOF >> /etc/hosts
              ${aws_network_interface.kubenode["loadbalancer"].private_ip} loadbalancer
              ${aws_network_interface.kubenode["controlplane01"].private_ip} controlplane01
              ${aws_network_interface.kubenode["controlplane02"].private_ip} controlplane02
              ${aws_network_interface.kubenode["controlplane03"].private_ip} controlplane03
              ${aws_network_interface.kubenode["node01"].private_ip} node01
              ${aws_network_interface.kubenode["node02"].private_ip} node02
              ${aws_network_interface.kubenode["node03"].private_ip} node03
              EOF
              echo "PRIMARY_IP=$(ip route | grep default | awk '{ print $9 }')" >> /etc/environment
              EOT
}


resource "aws_instance" "access_node" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t3.small"
  key_name      = aws_key_pair.kube_kp.key_name
  vpc_security_group_ids = [
    aws_security_group.access_node.id,
    aws_security_group.egress_all.id
  ]
  tags = merge(
    var.common_tags,
    {
    "Name" = "access_node"
    "Role" = "access-node"
  }
  )
  user_data = <<-EOT
              #!/usr/bin/env bash
              hostnamectl set-hostname "access-node"
              echo "${tls_private_key.key_pair.private_key_pem}" > /home/ubuntu/.ssh/id_rsa
              chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              curl -sS https://starship.rs/install.sh | sh -s -- -y
              echo 'eval "$(starship init bash)"' >> /home/ubuntu/.bashrc
              cat <<EOF >> /etc/hosts
              ${aws_network_interface.kubenode["loadbalancer"].private_ip} loadbalancer
              ${aws_network_interface.kubenode["controlplane01"].private_ip} controlplane01
              ${aws_network_interface.kubenode["controlplane02"].private_ip} controlplane02
              ${aws_network_interface.kubenode["controlplane03"].private_ip} controlplane03
              ${aws_network_interface.kubenode["node01"].private_ip} node01
              ${aws_network_interface.kubenode["node02"].private_ip} node02
              ${aws_network_interface.kubenode["node03"].private_ip} node03
              ${aws_network_interface.nfs_node.private_ip} nfs
              EOF
              EOT
}
resource "aws_network_interface" "nfs_node" {
  subnet_id       = data.aws_subnets.public.ids[0]
  security_groups = [aws_security_group.egress_all.id,
                    aws_security_group.nfs_node.id
                    ]
  tags = {
    Name = "nfs_node"
  }
}

resource "aws_instance" "nfs_node" {
  ami           = data.aws_ami.ubuntu.image_id
  instance_type = "t3.small"
  key_name      = aws_key_pair.kube_kp.key_name
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.nfs_node.id
  }
  tags = merge(
    var.common_tags,
    {
    "Name" = "nfs_node"
    "Role" = "nfs-node"
  }
  )
  user_data = <<-EOT
              #!/usr/bin/env bash
              hostnamectl set-hostname "nfs_node"
              echo "${tls_private_key.key_pair.private_key_pem}" > /home/ubuntu/.ssh/id_rsa
              chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              EOT
  
}

# Attach loadbalancer security group to loadbalancer ENI
resource "aws_network_interface_sg_attachment" "loadbalancer_sg_attachment" {
  security_group_id    = aws_security_group.loadbalancer.id
  network_interface_id = aws_instance.kubenode["loadbalancer"].primary_network_interface_id
}

# Attach controlplane and calico security groups to controlplane01 ENI
resource "aws_network_interface_sg_attachment" "controlplane01_sg_attachment" {
  security_group_id    = aws_security_group.controlplane.id
  network_interface_id = aws_instance.kubenode["controlplane01"].primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "controlplane01_sg_attachment_calico" {
  security_group_id    = aws_security_group.calico.id
  network_interface_id = aws_instance.kubenode["controlplane01"].primary_network_interface_id
}

# Attach controlplane and calico security groups to controlplane02 ENI
resource "aws_network_interface_sg_attachment" "controlplane02_sg_attachment" {
  security_group_id    = aws_security_group.controlplane.id
  network_interface_id = aws_instance.kubenode["controlplane02"].primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "controlplane02_sg_attachment_calico" {
  security_group_id    = aws_security_group.calico.id
  network_interface_id = aws_instance.kubenode["controlplane02"].primary_network_interface_id
}

# Attach controlplane and calico security groups to controlplane03 ENI
resource "aws_network_interface_sg_attachment" "controlplane03_sg_attachment" {
  security_group_id    = aws_security_group.controlplane.id
  network_interface_id = aws_instance.kubenode["controlplane03"].primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "controlplane03_sg_attachment_calico" {
  security_group_id    = aws_security_group.calico.id
  network_interface_id = aws_instance.kubenode["controlplane03"].primary_network_interface_id
}

# Attach workernodes and calico security groups to node01 ENI
resource "aws_network_interface_sg_attachment" "node01_sg_attachment" {
  security_group_id    = aws_security_group.workernode.id
  network_interface_id = aws_instance.kubenode["node01"].primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "node01_sg_attachment_calico" {
  security_group_id    = aws_security_group.calico.id
  network_interface_id = aws_instance.kubenode["node01"].primary_network_interface_id
}

# Attach workernodes and calico security groups to node02 ENI
resource "aws_network_interface_sg_attachment" "node02_sg_attachment" {
  security_group_id    = aws_security_group.workernode.id
  network_interface_id = aws_instance.kubenode["node02"].primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "node02_sg_attachment_calico" {
  security_group_id    = aws_security_group.calico.id
  network_interface_id = aws_instance.kubenode["node02"].primary_network_interface_id
}