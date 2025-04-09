#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo '<h1>Servidor Apache rodando na AWS EC2!</h1>' > /var/www/html/index.html
sudo yum install mod_ssl -y
sudo systemctl restart httpd
echo "Instalação do Apache concluída!"