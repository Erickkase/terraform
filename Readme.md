# 🚀 Infraestructura AWS - 5 Microservicios con Terraform

Infraestructura automatizada para desplegar 5 microservicios en AWS con Load Balancer, Auto-Scaling y 2 bases de datos (PostgreSQL + MySQL).

## 📋 ¿Qué incluye?

- **5 Microservicios** (service1 a service5) con 1 instancia cada uno
- **2 Bases de Datos**: PostgreSQL y MySQL con acceso público
- **Application Load Balancer** con rutas `/api/service1` a `/api/service5`
- **Auto-Scaling Groups** con escalado automático basado en CPU
- **Security Groups** configurados para acceso seguro

## ⚡ Inicio Rápido

### 1. Configurar variables
```powershell
# Edita terraform.tfvars con tus credenciales de AWS
notepad terraform.tfvars
```

### 2. Desplegar
```powershell
terraform init
terraform plan
terraform apply
```

### 3. Ver resultados
```powershell
terraform output
```

## 📚 Documentación

- **[INICIO-RAPIDO.md](INICIO-RAPIDO.md)** - Guía rápida de despliegue
- **[GUIA-WINDOWS.md](GUIA-WINDOWS.md)** - Guía completa para Windows (instalación, troubleshooting)
- **[README-DEPLOYMENT.md](README-DEPLOYMENT.md)** - Documentación técnica detallada

## 📝 Archivos Principales

| Archivo | Descripción |
|---------|-------------|
| `main.tf` | Configuración de toda la infraestructura |
| `variables.tf` | Definición de variables |
| `outputs.tf` | Outputs de recursos creados |
| `terraform.tfvars` | **TUS variables** (completar aquí) |
| `terraform.tfvars.example` | Plantilla de ejemplo |

## 🔒 Seguridad

⚠️ **NO subas a Git:**
- `terraform.tfvars` (contiene credenciales)
- `*.tfstate` (estado de la infraestructura)
- `*.pem` (llaves SSH)

Ya están en `.gitignore`.

## 🗑️ Destruir infraestructura

```powershell
terraform destroy
```

---

**¿Primera vez con Terraform?** Lee [GUIA-WINDOWS.md](GUIA-WINDOWS.md) primero.
