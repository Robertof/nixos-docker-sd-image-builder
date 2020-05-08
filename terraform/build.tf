# - NixOS SD image builder AWS configuration
# This will spin up a `a1.2xlarge` instance and build an SD image for NixOS on it using the
# contents of the cloned repository.
# Note that this will *not* copy the built image back onto the local machine. This can be done
# by using the provided `pull_image.sh` (which uses `scp`), uploading it to an S3 bucket or any
# other solution of your choice.

# This will automatically create an SSH key pair and export it as an output so that it can be
# used to connect to the remote host:
# 
# $ terraform apply
# ... NixOS SD image is built ...
# $ ./remote_ssh.sh
# admin@...:~$ ls *.img
# nixos-sd-image-20.03pre-git-aarch64-linux.img
# 
# If a build fails, instead of running Terraform again, just connect with SSH as shown above, fix
# the issue and execute `./run.sh`.
# 
# NOTE: do NOT forget to run `terraform destroy` once you are done!

variable "region" {
  default = "us-east-2"
}

variable "availability_zone" {
  # note: us-east-2c (used by default) does not have ARM spot instances
  default = "us-east-2a"
}

provider "aws" {
  profile    = "default"
  region     = var.region
}

# Using Debian for ARM as it has Docker and docker-compose easily available. The same is not true
# for the Amazon Linux AMI.
data "aws_ami" "debian" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-10-arm64-*"]
  }

  owners = ["136693071363"] # source: https://wiki.debian.org/Cloud/AmazonEC2Image/Buster
}

# Generate a temporary SSH keypair on demand.
# Unfortunately there is no support yet for ed25519 keys in Terraform.
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save the public key to AWS.
resource "aws_key_pair" "nixos_sd_image_builder_key" {
  key_name   = "nixos_sd_image_builder_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Request a spot instance.
resource "aws_spot_instance_request" "nixos_sd_image_builder" {
  ami                  = data.aws_ami.debian.id
  availability_zone    = var.availability_zone
  # This instance has 8 cores and 16 GiB of RAM. It is pretty cheap with Spot and builds the image
  # in about 5 minutes.
  instance_type        = "a1.2xlarge"
  wait_for_fulfillment = true
  spot_type            = "one-time"
  key_name             = aws_key_pair.nixos_sd_image_builder_key.key_name

  # The default volume size of 8 GiB is too small. Use 16.
  root_block_device {
    volume_type = "gp2"
    volume_size = "16"
  }

  # Use the generated keypair.
  connection {
    user        = "admin"
    private_key = tls_private_key.ssh_key.private_key_pem
    host        = aws_spot_instance_request.nixos_sd_image_builder.public_ip
  }

  # Copies Docker stuff.
  provisioner "file" {
    source      = "../docker"
    destination = "/home/admin/"
  }

  # Copies the run script.
  # NOTE: this won't be actually executed as the last `remote-exec` step copies the script in a
  # temporary directory, but we're copying anyway so that the build can be re-executed if needed.
  provisioner "file" {
    source      = "../run.sh"
    destination = "/home/admin/run.sh"
  }

  # Copies the configuration.
  # Note that this won't copy multiple '*.nix' files. Adjust as needed.
  provisioner "file" {
    source      = "../sd-card.nix"
    destination = "/home/admin/sd-card.nix"
  }

  # Installs dependencies and gets the run script ready for other re-executions.
  provisioner "remote-exec" {
    inline = [
      "chmod +x run.sh",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker.io docker-compose"
    ]
  }

  # Builds the image.
  provisioner "remote-exec" {
    script = "../run.sh"
  }

  # Friendly message.
  provisioner "local-exec" {
    command = <<EOF
      echo 'Build done.' &&
      echo ' If the build was successful, run `./pull_image.sh` to download the image file via SCP.' &&
      echo ' If the build failed,         run `./remote_ssh.sh` to SSH into the EC2 instance.' &&
      echo 'Do not forget to run `terraform destroy` when you are done!'
    EOF
  }
}

# Outputs the generated SSH key so that `remote_ssh.sh` and `pull_image.sh` work.
output "ssh_key" {
  sensitive = true
  value     = tls_private_key.ssh_key.private_key_pem
}

# Also outputs the instance public IP for obvious reasons.
output "instance_ip" {
  value = aws_spot_instance_request.nixos_sd_image_builder.public_ip
}
