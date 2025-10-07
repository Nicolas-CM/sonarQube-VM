provider "azurerm" {
  features {}
  subscription_id = "079ab1f2-9528-44da-ba22-d60a88fdb0b8"
}

# Grupo de recursos
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Red virtual
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subred
resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# IP pública
resource "azurerm_public_ip" "public_ip" {
  name                = "${var.prefix}-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Security Group (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Regla SSH
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Regla para SonarQube
  security_rule {
    name                       = "SonarQube"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Interfaz de red
resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Asociación de la NIC con el NSG
resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Máquina virtual
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb        = 30  # Aumentado para SonarQube
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Script de inicialización para instalar Java y SonarQube
  custom_data = base64encode(<<-EOF
              #!/bin/bash
              # Actualizar el sistema
              sudo apt update
              sudo apt upgrade -y

              # Instalar Java 17
              sudo apt install openjdk-17-jdk -y

              # Instalar unzip
              sudo apt install unzip -y

              # Descargar e instalar SonarQube
              wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.0.87286.zip
              unzip sonarqube-10.4.0.87286.zip
              sudo mv sonarqube-10.4.0.87286 /opt/sonarqube

              # Crear grupo y usuario sonar
              sudo groupadd sonar
              sudo useradd -r -g sonar sonar
              sudo chown -R sonar:sonar /opt/sonarqube
              sudo chmod +x /opt/sonarqube/bin/linux-x86-64/sonar.sh

              # Crear servicio systemd para SonarQube
              sudo tee /etc/systemd/system/sonarqube.service << 'EOL'
              [Unit]
              Description=SonarQube service
              After=syslog.target network.target

              [Service]
              Type=simple
              ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh console
              User=sonar
              Group=sonar
              Restart=always
              LimitNOFILE=65536
              LimitNPROC=4096

              [Install]
              WantedBy=multi-user.target
              EOL

              # Configurar límites del sistema
              sudo tee -a /etc/security/limits.conf << 'EOL'
              sonar   -   nofile   65536
              sonar   -   nproc    4096
              EOL

              # Configurar variables del sistema
              sudo tee -a /etc/sysctl.conf << 'EOL'
              vm.max_map_count=262144
              fs.file-max=65536
              EOL

              # Aplicar cambios
              sudo sysctl -p

              # Iniciar SonarQube
              sudo systemctl daemon-reload
              sudo systemctl enable sonarqube
              sudo systemctl start sonarqube
              EOF
  )
}