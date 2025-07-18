# Security group for egress to anywhere.
# Will be applied to all EC2 instances
resource "aws_security_group" "egress_all" {
  name   = "egress_all"
  vpc_id = data.aws_vpc.default_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_vpc" {
  name   = "ingress_vpc"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.default_vpc.cidr_block]
  }
}

# Security group for ingress to access_node host.
# Permits only cloudshell and EC2 instance connect to connect to it
resource "aws_security_group" "access_node" {
  name   = "access_node"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    description = "Login SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      data.localos_public_ip.cloudshell_ip.cidr
    ]
  }

  ingress {
    description = "EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "18.206.107.24/29"
    ]
  }

  ingress {
    description = "allow kubectl port-forward on access node"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for ingress to loadbalancer host.
# Permits only cloudshell and EC2 instance connect to connect to it
resource "aws_security_group" "loadbalancer" {
  name   = "loadbalancer"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    # Allow SSH from access-node
    description = "Login SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [
      aws_security_group.access_node.id
    ]
  }

  ingress {
    description = "EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "18.206.107.24/29"
    ]
  }

  ingress {
    # Allow API server access from anywhere in VPC
    description = "API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [
      data.aws_vpc.default_vpc.cidr_block
    ]
  }
}

# Security group for ingress to controlplane
resource "aws_security_group" "controlplane" {
  name   = "controlplane"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    # Allow SSH from access-node
    description = "Login SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [
      aws_security_group.access_node.id
    ]
  }

  ingress {
    # Allow API server access only from loadbalancer
    description = "API Server from LB"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    security_groups = [
      aws_security_group.loadbalancer.id
    ]
  }

  ingress {
    # Allow etcd access from access-node
    # e.g. to run etcdctl
    description = "etcd frorm SN"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    security_groups = [
      aws_security_group.access_node.id
    ]
  }
}

# Additional rules for control plane SG to allow
# control plane components to talk to each other
resource "aws_vpc_security_group_ingress_rule" "controlplane_etcd" {
  description                  = "etcd gossip"
  ip_protocol                  = "tcp"
  from_port                    = 2379
  to_port                      = 2380
  security_group_id            = aws_security_group.controlplane.id
  referenced_security_group_id = aws_security_group.controlplane.id
}

resource "aws_vpc_security_group_ingress_rule" "controlplane_scheduler" {
  description                  = "kubeschduler gossip"
  ip_protocol                  = "tcp"
  from_port                    = 10259
  to_port                      = 10259
  security_group_id            = aws_security_group.controlplane.id
  referenced_security_group_id = aws_security_group.controlplane.id
}

resource "aws_vpc_security_group_ingress_rule" "controlplane_cm" {
  description                  = "controller-manager gossip"
  ip_protocol                  = "tcp"
  from_port                    = 10257
  to_port                      = 10257
  security_group_id            = aws_security_group.controlplane.id
  referenced_security_group_id = aws_security_group.controlplane.id
}

# Security group for ingress to worker nodes
resource "aws_security_group" "workernode" {
  name   = "workernode"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    # Allow SSH from access-node
    description = "Login SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [
      aws_security_group.access_node.id
    ]
  }

  ingress {
    # Allow SSH from any host that has controlplane security group
    description = "kubelet api"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    security_groups = [
      aws_security_group.controlplane.id
    ]
  }

  ingress {
    # Allow access to node ports from your workstation
    # and access node
    description = "Node Ports"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [
      # Note - insecure. Anyone can connect to node ports.
      "0.0.0.0/0"
    ]

  }
}

# Security group for communication between calico pods
# Applied to all nodes
resource "aws_security_group" "calico" {
  name   = "calico"
  vpc_id = data.aws_vpc.default_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "calico_bgp" {
  description                  = "bgp"
  from_port                    = 179
  to_port                      = 179
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.calico.id
  referenced_security_group_id = aws_security_group.calico.id
}

resource "aws_vpc_security_group_ingress_rule" "calico_ip_in_ip" {
  description                  = "ip-in-ip"
  ip_protocol                  = "4"
  security_group_id            = aws_security_group.calico.id
  referenced_security_group_id = aws_security_group.calico.id
}

resource "aws_vpc_security_group_ingress_rule" "calico_vxlan" {
  description                  = "vxlan"
  from_port                    = 4789
  to_port                      = 4789
  ip_protocol                  = "udp"
  security_group_id            = aws_security_group.calico.id
  referenced_security_group_id = aws_security_group.calico.id
}

resource "aws_vpc_security_group_ingress_rule" "calico_typha" {
  description                  = "typha"
  from_port                    = 5473
  to_port                      = 5473
  ip_protocol                  = "tcp"
  security_group_id            = aws_security_group.calico.id
  referenced_security_group_id = aws_security_group.calico.id
}

resource "aws_vpc_security_group_ingress_rule" "calico_wireguard" {
  description                  = "wireguard"
  from_port                    = 51820
  to_port                      = 51821
  ip_protocol                  = "udp"
  security_group_id            = aws_security_group.calico.id
  referenced_security_group_id = aws_security_group.calico.id
}


# Calico daemonsets seem to require this port
resource "aws_vpc_security_group_ingress_rule" "calico_apiserver" {
  description                  = "api-server gossip"
  ip_protocol                  = "tcp"
  from_port                    = 6443
  to_port                      = 6443
  security_group_id            = aws_security_group.calico.id
  referenced_security_group_id = aws_security_group.calico.id
}

# Security group for NFS node
resource "aws_security_group" "nfs_node" {
  name   = "nfs_node"
  vpc_id = data.aws_vpc.default_vpc.id
    ingress {
        # Allow NFS access from all nodes
        description = "NFS access"
        from_port   = 2049
        to_port     = 2049
        protocol    = "tcp"
        security_groups = [
        aws_security_group.workernode.id,
        aws_security_group.controlplane.id
        ]
    }
    ingress {
        # Allow SSH from access-node
        description = "Login SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        security_groups = [
            aws_security_group.access_node.id
        ]

    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Add to controlplane SG: Allow worker nodes to access API server
resource "aws_vpc_security_group_ingress_rule" "controlplane_apiserver_from_workers" {
  description       = "API Server from Workers"
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  security_group_id = aws_security_group.controlplane.id
  referenced_security_group_id = aws_security_group.workernode.id  # Allow workers
}

# Add to workernode SG: Allow self-traffic for kubelet
resource "aws_vpc_security_group_ingress_rule" "workernode_kubelet_self" {
  description       = "Kubelet from same SG"
  ip_protocol       = "tcp"
  from_port         = 10250
  to_port           = 10250
  security_group_id = aws_security_group.workernode.id
  referenced_security_group_id = aws_security_group.workernode.id  # Allow self
}