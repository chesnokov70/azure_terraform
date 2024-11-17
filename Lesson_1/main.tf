terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0, <4.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "ches_rg" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_virtual_network" "ches_vn" {
  name                = "ches-vn"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.ches_rg.location
  resource_group_name = azurerm_resource_group.ches_rg.name
}

#----------------------------------------------
resource "azurerm_public_ip" "ches_public_ip" {
  name                = "ches-public-ip"
  resource_group_name = azurerm_resource_group.ches_rg.name
  location            = azurerm_resource_group.ches_rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}

#-------------------------------------------------------
resource "azurerm_network_security_group" "ches_sg" {
  name                = "ches-sg" # Updated for consistency
  location            = azurerm_resource_group.ches_rg.location
  resource_group_name = azurerm_resource_group.ches_rg.name

  tags = {
    Environment = "dev"
  }
}

#-------------------------------------------------------
resource "azurerm_network_security_rule" "ches_allow_ssh" {
  name                        = "AllowSSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.ches_rg.name
  network_security_group_name = azurerm_network_security_group.ches_sg.name
}

#---------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "ches_sg_association" {
  subnet_id                 = azurerm_subnet.ches_subnet.id
  network_security_group_id = azurerm_network_security_group.ches_sg.id
}

#------------------------------------------------
resource "azurerm_subnet" "ches_subnet" {
  name                 = "ches_subnet"
  resource_group_name  = azurerm_resource_group.ches_rg.name
  virtual_network_name = azurerm_virtual_network.ches_vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

#-----------------------------------------------
resource "azurerm_network_interface" "ches_ni" {
  name                = "ches-ni"
  location            = azurerm_resource_group.ches_rg.location
  resource_group_name = azurerm_resource_group.ches_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ches_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ches_public_ip.id
  }

  tags = {
    environment = "dev"
  }

}

resource "azurerm_linux_virtual_machine" "ches_lvm" {
  name                  = "my-ubuntu-VM"
  resource_group_name   = azurerm_resource_group.ches_rg.name
  location              = azurerm_resource_group.ches_rg.location
  size                  = "Standard_F2"
  admin_username        = "adminuser" # Make sure this is correct
  network_interface_ids = [azurerm_network_interface.ches_ni.id]

  custom_data = filebase64("customdata.tpl")


  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/mtc_azure_key.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

 provisioner "local-exec" {
    command = var.host_os == "windows" ? "PowerShell -Command \"Add-Content -Path 'C:/Users/Denis/.ssh/config' -Value 'Host ${self.public_ip_address} ...'" : "echo \"Host ${self.public_ip_address} ...\" >> ~/.ssh/config"
    interpreter = var.host_os == "windows" ? ["PowerShell", "-Command"] : ["bash", "-c"]
  }

tags= {
  environment = "dev"
}

}

#------------------------------data----------------------------------------

data "azurerm_public_ip" "ches_public_ip" {
  name = azurerm_public_ip.ches_public_ip.name
  resource_group_name = azurerm_resource_group.ches_rg.name
}

#-----------------------------output---------------------------------------
output "azurerm_public_ip" {
  value = "${azurerm_linux_virtual_machine.ches_lvm.name}: ${data.azurerm_public_ip.ches_public_ip.ip_address}"
}

output "resource_group_name" {
  value = azurerm_resource_group.ches_rg.name
}

output "resource_group_location" {
  value = azurerm_resource_group.ches_rg.location
}
