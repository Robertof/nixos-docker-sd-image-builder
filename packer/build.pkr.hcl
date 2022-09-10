# - NixOS SD image builder AWS configuration
# This will spin up a `a1.2xlarge` instance and build an SD image for NixOS on it using the
# contents of the cloned repository. It will also automatically download the image from the
# remote instance.
# I recommend to enable compression in the main configuration file to minimize downloading
# files.
#
# NOTE: This requires at least Packer 1.5.0.

variable "region" {
  default = "us-east-1"
}

variable "availability_zone" {
  default = "us-east-1a"
}

source "amazon-ebs" "nixos_sd_image_builder" {
  ami_name            = "nixos_sd_image_builder"
  region              = var.region
  availability_zone   = var.availability_zone
  # This instance has 8 cores and 16 GiB of RAM. It is pretty cheap with Spot and builds the image
  # in about 5 minutes.
  spot_instance_types = ["a1.2xlarge"]
  spot_price          = "auto"
  skip_create_ami     = true

  fleet_tags = {
    # Workaround for https://github.com/hashicorp/packer-plugin-amazon/issues/92
    Name = "nixos_sd_image_builder-{{ timestamp }}"
  }

  source_ami_filter {
    filters = {
      name = "debian-11-arm64-*"
    }

    most_recent = true

    owners = ["136693071363"] # source: https://wiki.debian.org/Cloud/AmazonEC2Image/Bullseye
  }

  # The default volume size of 8 GiB is too small. Use 16.
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_type           = "gp2"
    volume_size           = "16"
    delete_on_termination = true
  }

  ssh_username = "admin"
  ssh_interface = "public_ip"
}

build {
  sources = ["source.amazon-ebs.nixos_sd_image_builder"]

  # Copies Docker stuff.
  provisioner "file" {
    source      = "../docker"
    destination = "./"
  }

  # Copies the run script.
  # NOTE: this won't be actually executed, as the last `shell` step copies the script in a
  # temporary directory, but we're copying anyway so that the build can be re-executed if needed.
  provisioner "file" {
    source      = "../run.sh"
    destination = "./run.sh"
  }

  # Copies the configuration file(s).
  provisioner "file" {
    source      = "../config"
    destination = "./"
  }

  # Installs dependencies and gets the run script ready for other re-executions.
  provisioner "shell" {
    inline = [
      "chmod +x run.sh",
      "curl -fsSL https://get.docker.com | sh"
    ]
  }

  # Builds the image.
  provisioner "shell" {
    script = "../run.sh"
  }

  # Downloads the image.
  provisioner "file" {
    source      = "./nixos*"
    destination = "./"
    direction   = "download"
  }

  provisioner "shell-local" {
    inline = [
      "echo 'Image *successfully* built and downloaded as' nixos*"
    ]
  }
}
