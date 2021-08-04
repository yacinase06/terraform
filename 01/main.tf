# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg-terraform" {
  name     = var.resource_01_group_name
  location = var.location
  tags = {

    Environment = "Terraform Demo"
    To_Delete   = "Yes"
  }
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet-terraform" {
  name                = var.vnet_01_name
  resource_group_name = azurerm_resource_group.rg-terraform.name
  location            = azurerm_resource_group.rg-terraform.location
  address_space       = ["10.0.0.0/16"]
  tags = {

    Environment = "Terraform Demo"
    To_Delete   = "Yes"
  }
}


# Create subnet
resource "azurerm_subnet" "subnet-01-terraform" {
    name                 = var.subnet_01_name
    resource_group_name  = azurerm_resource_group.rg-terraform.name
    virtual_network_name = azurerm_virtual_network.vnet-terraform.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "pip-01-terraform" {
    name                         = var.pip_01_name
    location                     = var.location
    resource_group_name          = azurerm_resource_group.rg-terraform.name
    allocation_method            = "Dynamic"
  tags = {

    Environment = "Terraform Demo"
    To_Delete   = "Yes"
  }

}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg-01-terraform" {
    name                = var.nsg_01_name
    location            = var.location
    resource_group_name = azurerm_resource_group.rg-terraform.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
  tags = {

    Environment = "Terraform Demo"
    To_Delete   = "Yes"
  }


}

# Create network interface
resource "azurerm_network_interface" "nic-01-terraform" {
    name                      = var.nic_01_name
    location                  = var.location
    resource_group_name       = azurerm_resource_group.rg-terraform.name

    ip_configuration {
        name                          = "nic-01-config-terraform"
        subnet_id                     = azurerm_subnet.subnet-01-terraform.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.pip-01-terraform.id
    }

      tags = {

    Environment = "Terraform Demo"
    To_Delete   = "Yes"
  }    
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.nic-01-terraform.id
    network_security_group_id = azurerm_network_security_group.nsg-01-terraform.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.rg-terraform.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage-account-01-terraform" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.rg-terraform.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.example_ssh.private_key_pem 
    sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "vm-01-terraform" {
    name                  = var.vm_01_name
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg-terraform.name
    network_interface_ids = [azurerm_network_interface.nic-01-terraform.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = var.os_disk_01_name
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = var.vm_01_name
    admin_username = var.admin_user
    disable_password_authentication = true

    admin_ssh_key {
        username       = var.admin_user
        public_key     = file("C:\\Users\\BENAMRIY\\Documents\\MobaXterm\\home\\.ssh\\keys\\id_rsa.pub")
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storage-account-01-terraform.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}
