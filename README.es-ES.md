# Proxmox Private Cloud

![Architecture](.assets/Architecture.svg)

**Construye y opera una nube privada local en Proxmox VE, desde la configuración del hipervisor bare-metal hasta la observabilidad de stack completo — todo automatizado con Packer, OpenTofu y Ansible.**

Este repositorio te guía a través de todo el recorrido: endurecimiento (hardening) de un host de Proxmox, creación de imágenes de VM estandarizadas con Packer, despliegue mediante OpenTofu, configuración de todo con Ansible, despliegue de un servidor de Minecraft con un túnel público de ngrok, y supervisión de todo el conjunto con Grafana, Prometheus, Loki y Alloy. Cada fase tiene una publicación correspondiente en Medium si deseas conocer los detalles.

---

## Inicio rápido con Devbox

Este proyecto utiliza [devbox](https://www.jetify.com/devbox) para gestionar las herramientas. Todas las herramientas necesarias (Packer, OpenTofu, Ansible) se instalan automáticamente.

```bash
# Entrar en el shell de devbox (instala todos los paquetes)
devbox shell

# O ejecutar comandos individuales sin entrar en el shell
devbox run help
```

### Comandos de Devbox disponibles

| Comando | Fase | Descripción |
|---------|-------|-------------|
| `devbox run help` | — | Muestra todos los comandos disponibles |
| `devbox run packer:build-iso` | II | Construye una plantilla de VM desde una imagen ISO |
| `devbox run packer:build-clone` | II | Construye una plantilla de VM desde una VM existente |
| `devbox run tofu:plan` | II | Previsualiza los cambios de infraestructura de OpenTofu |
| `devbox run tofu:apply` | II | Aplica la infraestructura de OpenTofu |
| `devbox run ansible:deploy-minecraft` | V | Despliega el servidor de Minecraft + túnel ngrok |
| `devbox run ansible:setup-monitoring` | IV | Despliega el stack de monitoreo (configura la IP en inventory.ini primero) |
| `devbox run ansible:register-vm` | IV | Registra una VM con Alloy (usa `-l IP` para el objetivo) |
| `devbox run ansible:unregister-vm` | IV | Elimina Alloy de una VM (usa `-l IP` para el objetivo) |

Si no utilizas devbox, ejecuta `./setup-env.sh` para instalar Packer, OpenTofu y Ansible manualmente.

> **Antes del despliegue** — reemplaza todos los marcadores de posición `CHANGEME_*` en todo el repositorio
> por tus valores reales (IPs, tokens de API, contraseñas). Aparecen en:
> `04 - observability & monitoring/configs/`, `04 - observability & monitoring/ansible/`,
> `04 - observability & monitoring/terraform/`, `02 - provisioning/02 - OpenTofu-Terraform/variables.tf`,
> y `devbox.json`.

---

## Estructura del Proyecto

```
proxmox-private-cloud/
├── 01 - core-setup/                       # Fase I — Instalación y endurecimiento de Proxmox
│   ├── post-install.sh                    #   script de optimización de extremeshok
│   └── README.md                          #   Guía de configuración y recomendaciones de producción
├── 02 - provisioning/                     # Fase II — Creación de imágenes de VM y aprovisionamiento
│   ├── 01 - Packer/                       #   Plantillas de Packer (ISO + Clone)
│   │   ├── ISO/                           #     Construcción desde ISO con cloud-init
│   │   ├── Clone/                         #     Construcción desde plantilla existente
│   │   └── README.md
│   └── 02 - OpenTofu-Terraform/           #   Infraestructura como Código para el despliegue de VMs
│       ├── main.tf                        #     Definiciones de recursos de VM
│       ├── provider.tf                    #     Configuración del proveedor de Proxmox
│       ├── variables.tf                   #     Variables de entrada
│       └── README.md
├── 03 - configuration/                    # Fase III — Gestión de configuración con Ansible
│   └── ansible/
│       ├── main.yaml                      #   Orquestador de playbooks
│       ├── playbooks/                     #   init, usuarios, seguridad, minecraft
│       └── README.md
├── 04 - observability & monitoring/        # Fase IV — Stack de observabilidad
│   ├── ansible/                           #   Playbooks para la VM de monitoreo y VMs objetivo
│   ├── configs/                           #   Configuraciones de Grafana, Prometheus, Loki, Alloy
│   ├── terraform/                         #   OpenTofu para la propia VM de monitoreo
│   ├── docker-compose.yml                 #   Definición de servicios de monitoreo
│   └── README.md
├── 05 - minecraft/                         # Fase V — Minecraft + túnel ngrok
├── .assets/                               # Diagramas y activos del proyecto
│   ├── Architecture.svg
│   ├── ngrok_mc_tunnel.svg
│   └── Observation_Architecture.svg
├── devbox.json                            # Configuración de paquetes y scripts de Devbox
├── devbox.lock                            # Archivo de bloqueo de Devbox
├── setup-env.sh                           # Script legado de configuración del entorno
├── README.md                              # Este archivo
└── LICENSE                                # Licencia MIT
```

---

## Resúmenes de las Fases

### Fase I — Configuración Core

**Fundación de Proxmox lista para producción.**

Endurece una instalación fresca de Proxmox VE 9.1 — repositorios, firewall, 2FA, SSH y el script de optimización de extremeshok. También cubre detalles post-instalación como zona horaria, DNS y notificaciones por correo electrónico.

**Directorio:** [`01 - core-setup/`](./01%20-%20core-setup/README.md)

---

### Fase II — Aprovisionamiento (Packer + OpenTofu)

**Creación automatizada de imágenes de VM e infraestructura como código.**

Packer construye plantillas de VM estandarizadas desde una ISO o VMs existentes usando cloud-init. OpenTofu (compatible con Terraform) despliega VMs desde esas plantillas con una configuración reproducible. Ambos utilizan autenticación por token de API e incluyen el QEMU Guest Agent.

**Directorios:**
- [`02 - provisioning/01 - Packer/`](./02%20-%20provisioning/01%20-%20Packer/README.md)
- [`02 - provisioning/02 - OpenTofu-Terraform/`](./02%20-%20provisioning/02%20-%20OpenTofu-Terraform/README.md)

---

### Fase III — Configuración (Ansible)

**Gestión de configuración idempotente para cada VM.**

Playbooks modulares que manejan la inicialización del sistema, gestión de usuarios, endurecimiento de seguridad y despliegue de aplicaciones. La seguridad incluye autenticación solo mediante llaves SSH, fail2ban y UFW con denegación por defecto. Los secretos residen en Ansible Vault.

**Directorio:** [`03 - configuration/ansible/`](./03%20-%20configuration/ansible/README.md)

---

### Fase IV — Observabilidad y Monitoreo

**Observabilidad de stack completo con Grafana, Prometheus, Loki y Grafana Alloy.**

Alloy se ejecuta como un colector unificado en cada VM objetivo (reemplazando los agentes separados de Node Exporter, cAdvisor y Promtail). Prometheus gestiona las métricas y alertas, Loki absorbe los logs con una retención de 30 días, y PVE Exporter integra las métricas del host de Proxmox. Alertmanager envía notificaciones a Discord y los dashboards de Grafana se aprovisionan automáticamente. Todos los secretos están en el vault.

**Directorio:** [`04 - observability & monitoring/`](./04%20-%20observability%20&%20monitoring/README.md)

---

### Fase V — Servidor de Minecraft + Túnel ngrok

Un servidor de Minecraft Java Edition ejecutándose en Docker con un tipo de servidor Paper, autenticación crackeada (online_mode=false) y un contenedor sidecar de ngrok que abre un túnel TCP público para que cualquiera pueda unirse. El playbook espera a que el túnel esté activo e imprime la dirección al final — sin tener que buscar en los logs. Reside en la misma VM que ejecuta Alloy de la Fase IV, por lo que el stack de observabilidad lo detecta automáticamente.

**Directorio:** [`05 - minecraft/`](./05%20-%20minecraft/README.md)

---

## Referencias

Este proyecto acompaña a una serie de artículos en Medium:

- [How to Build a Local Private Cloud — Part I: Proxmox](https://medium.com/@0xA1M/how-to-build-a-local-private-cloud-part-i-proxmox-f118b146ebd8)
- [Phase II — Part 1: Automating VM Provisioning in Proxmox w/ Packer](https://medium.com/@0xA1M/phase-ii-part-1-automating-vm-provisioning-in-proxmox-w-packer-aafdd4231db2)
- [Phase II — Part 2: Automating VM Provisioning in Proxmox w/ Terraform/OpenTofu](https://medium.com/@0xA1M/phase-ii-part-2-automating-vm-provisioning-in-proxmox-w-terraform-opentofu-ec14ad931bfb)
- [Phase III — Automating VM Configuration Using Ansible](https://medium.com/@0xA1M/phase-iii-automating-vm-configuration-using-ansible-a51956395590)
- [Phase IV — Your Own Little Palantír w/ LGTM Stack](https://medium.com/@0xA1M/phase-vi-your-own-little-palantir-w-lgtm-stack-fcdeb8a40304)
- [Phase V — The 2 Week Minecraft Phase](https://medium.com/@0xA1M/phase-v-the-2-week-minecraft-phase-00bf8505cb46)

---

## Licencia

[MIT License](LICENSE) — use, modifique y comparta libremente.
