# Cluster K3s sur AWS avec Terraform

Ce projet Terraform configure une infrastructure complète pour déployer un cluster Kubernetes K3s sur AWS.

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration](#configuration)
- [Déploiement](#déploiement)
- [Accès au cluster](#accès-au-cluster)
- [Ressources créées](#ressources-créées)
- [Maintenance](#maintenance)
- [Nettoyage](#nettoyage)

## 🎯 Vue d'ensemble

Ce projet Terraform déploie un cluster Kubernetes K3s sur AWS composé de :
- **1 nœud Master** (contrôleur du cluster)
- **2 nœuds Worker** (exécution des workloads)

Tous les nœuds utilisent des instances EC2 **t3.medium** avec **20 GB** de stockage SSD (gp3) et bénéficient d'adresses IP élastiques (EIP) fixes.

### En clair, ce code fait quoi ?

**Simplement : il crée automatiquement 3 serveurs dans le cloud AWS prêts à fonctionner ensemble comme un cluster Kubernetes.**

À l'exécution, le code :
1. **Crée un réseau privé** (VPC avec DNS activé) pour que les 3 serveurs communiquent entre eux
2. **Crée 3 serveurs Ubuntu** avec chacun 20 GB de disque chiffré
3. **Configure les règles de sécurité** pour autoriser le trafic nécessaire (SSH, ports Kubernetes, HTTP/HTTPS)
4. **Ajoute une clé SSH** pour pouvoir se connecter en ligne de commande
5. **Assigne des adresses IP élastiques fixes** — les IPs ne changent pas même après redémarrage

Une fois déployé, tu peux installer K3s sur ces 3 serveurs et lancer des applications en conteneurs.

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│        VPC (192.168.2.0/24)             │
│        DNS activé                        │
├─────────────────────────────────────────┤
│  ┌──────────────────────────────────┐   │
│  │  Subnet public (us-east-1a)      │   │
│  │  192.168.2.0/24                  │   │
│  ├──────────────────────────────────┤   │
│  │ k3s-cluster-master   (192.168.2.10) │ │
│  │ k3s-cluster-worker-1 (192.168.2.11) │ │
│  │ k3s-cluster-worker-2 (192.168.2.12) │ │
│  └──────────────────────────────────┘   │
│                                          │
│  Internet Gateway                        │
│  Route Table (0.0.0.0/0 → IGW)          │
│  Security Group (K3s ports)              │
│  3 × Elastic IPs (fixes)                │
└─────────────────────────────────────────┘
```

## 📦 Prérequis

### Outils nécessaires

- **Terraform** >= 1.0 ([Installation](https://www.terraform.io/downloads.html))
- **AWS CLI** >= 2.0 ([Installation](https://aws.amazon.com/fr/cli/))
- **Compte AWS** avec permissions suffisantes
- **Clé SSH** générée localement

### Permissions AWS requises

Votre utilisateur AWS doit avoir accès à :
- EC2 (instances, security groups, key pairs, EIP)
- VPC (VPC, subnets, internet gateways, route tables)

## 🚀 Installation

### 1. Cloner le projet

```bash
git clone https://github.com/CL-KRMA/aws-terraform-config
cd aws-terraform-config
```

### 2. Générer une clé SSH

```bash
mkdir -p keys
ssh-keygen -t rsa -b 4096 -f keys/ma-cle-ssh -N ""
```

Cette commande crée :
- `keys/ma-cle-ssh` (clé privée — ne jamais partager)
- `keys/ma-cle-ssh.pub` (clé publique — utilisée par Terraform)

### 3. Configurer les credentials AWS

```bash
aws configure
```

Entrez :
- AWS Access Key ID
- AWS Secret Access Key
- Region : `us-east-1`
- Format de sortie : `json`

## ⚙️ Configuration

### Variables disponibles dans `main.tf`

| Variable | Valeur par défaut | Description |
|---|---|---|
| `region` | `us-east-1` | Région AWS |
| `instance_type` | `t3.medium` | Type d'instance EC2 |
| `ami_id` | `ami-08c40ec9ead489470` | Ubuntu 22.04 LTS |
| `volume_size` | `20` | Taille du disque en GB |
| `key_name` | `ma-cle-ssh` | Nom de la clé SSH |
| `project_name` | `k3s-cluster` | Préfixe des ressources AWS |
| `allowed_ssh_cidr` | `0.0.0.0/0` | CIDR autorisé pour SSH |

> **Sécurité** : En production, remplace `allowed_ssh_cidr` par ton IP (`x.x.x.x/32`) pour restreindre l'accès SSH.

### Exemple de personnalisation

```hcl
# terraform.tfvars
project_name     = "mon-projet"
instance_type    = "t3.large"
allowed_ssh_cidr = "203.0.113.0/32"  # ton IP uniquement
```

## 🎬 Déploiement

### Étape 1 : Initialiser Terraform

```bash
terraform init
```

### Étape 2 : Planifier le déploiement

```bash
terraform plan -out=tfplan
```

Vérifie que **19 ressources** vont être créées (VPC, subnet, IGW, route table, SG, key pair, 3 instances, 3 EIP).

### Étape 3 : Appliquer la configuration

```bash
terraform apply tfplan
```

Comptez **5-10 minutes** pour que tout soit opérationnel.

### Étape 4 : Récupérer les informations du cluster

```bash
terraform output
```

Exemple de résultat :
```
nodes = {
  master   = { private_ip = "192.168.2.10", public_ip = "54.x.x.x", role = "master" }
  worker-1 = { private_ip = "192.168.2.11", public_ip = "54.x.x.x", role = "worker" }
  worker-2 = { private_ip = "192.168.2.12", public_ip = "54.x.x.x", role = "worker" }
}

ssh_commands = {
  master   = "ssh -i keys/ma-cle-ssh ubuntu@54.x.x.x"
  worker-1 = "ssh -i keys/ma-cle-ssh ubuntu@54.x.x.x"
  worker-2 = "ssh -i keys/ma-cle-ssh ubuntu@54.x.x.x"
}
```

## 🔌 Accès au cluster

### Connexion SSH

Utilise les commandes générées par `terraform output ssh_commands` :

```bash
# Master
ssh -i keys/ma-cle-ssh ubuntu@<MASTER_PUBLIC_IP>

# Worker 1
ssh -i keys/ma-cle-ssh ubuntu@<WORKER1_PUBLIC_IP>

# Worker 2
ssh -i keys/ma-cle-ssh ubuntu@<WORKER2_PUBLIC_IP>
```

### Installation de K3s

**Sur le master :**

```bash
curl -sfL https://get.k3s.io | sh -

# Récupérer le token pour les workers
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Sur chaque worker (répéter pour worker-1 et worker-2) :**

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.2.10:6443 \
  K3S_TOKEN=<TOKEN> sh -
```

**Vérifier que le cluster est opérationnel :**

```bash
sudo kubectl get nodes
# NAME       STATUS   ROLES                  AGE
# master     Ready    control-plane,master   2m
# worker-1   Ready    <none>                 1m
# worker-2   Ready    <none>                 1m
```

## 📦 Ressources créées

### Réseau
| Ressource | Nom Terraform | Description |
|---|---|---|
| VPC | `aws_vpc.main` | Réseau privé avec DNS activé |
| Subnet | `aws_subnet.public` | Subnet public us-east-1a |
| Internet Gateway | `aws_internet_gateway.main` | Accès internet |
| Route Table | `aws_route_table.public` | Routage vers IGW |

### Sécurité
| Port | Protocole | Source | Usage |
|---|---|---|---|
| 22 | TCP | `allowed_ssh_cidr` | SSH |
| ICMP | - | `allowed_ssh_cidr` | Ping |
| 6443 | TCP | VPC interne | K3s API Server |
| 8472 | UDP | VPC interne | K3s VXLAN (Flannel) |
| 10250 | TCP | VPC interne | Kubelet |
| 30000-32767 | TCP | 0.0.0.0/0 | NodePorts |
| 80 | TCP | 0.0.0.0/0 | HTTP |
| 443 | TCP | 0.0.0.0/0 | HTTPS |

### Instances EC2
| Nœud | IP privée | Type | Disque | Role |
|---|---|---|---|---|
| master | 192.168.2.10 | t3.medium | 20GB gp3 chiffré | control-plane |
| worker-1 | 192.168.2.11 | t3.medium | 20GB gp3 chiffré | worker |
| worker-2 | 192.168.2.12 | t3.medium | 20GB gp3 chiffré | worker |

> Chaque instance a une **Elastic IP fixe** — l'IP ne change pas après redémarrage.

## 🔧 Maintenance

### Voir l'état actuel

```bash
terraform show
terraform output
```

### Modifier le type d'instance

```bash
# Dans main.tf ou terraform.tfvars
instance_type = "t3.large"

terraform plan   # vérifier l'impact
terraform apply  # appliquer
```

### Sauvegarder l'état Terraform

```bash
# Copier le state dans S3 (recommandé en équipe)
terraform init -backend-config="bucket=mon-bucket-tfstate"
```

> **Important** : Ne jamais modifier `terraform.tfstate` manuellement.

## 🗑️ Nettoyage

Pour détruire toutes les ressources et éviter les frais AWS :

```bash
terraform destroy
```

Confirme en tapant `yes`. Toutes les ressources (instances, EIP, VPC, SG) seront supprimées.

## 📊 Coûts estimés

| Ressource | Quantité | Coût/mois |
|---|---|---|
| t3.medium (on-demand) | 3 | ~$120 |
| EIP attachées à une instance | 3 | $0 |
| gp3 20GB | 3 | ~$5 |
| **Total** | | **~$125/mois** |

> Pour réduire les coûts : utilise des **Spot Instances** (économie de 60-70%) ou éteins les instances quand tu ne les utilises pas (`terraform apply -var="instance_count=0"`).

## 🐛 Dépannage

### "Terraform not found"
Installe Terraform : https://www.terraform.io/downloads.html

### "AWS credentials not found"
Exécute `aws configure` avec tes clés d'accès.

### "Permission denied (publickey)"
```bash
chmod 600 keys/ma-cle-ssh
```

### Les workers ne rejoignent pas le master
Vérifie que le DNS est activé sur le VPC et que le port 6443 est accessible depuis le subnet interne.

### Les instances mettent longtemps à démarrer
Normal — AWS a besoin de 5-10 minutes pour initialiser les ressources.

## 📚 Ressources

- [Documentation Terraform AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentation K3s](https://docs.k3s.io/)
- [Documentation AWS VPC](https://docs.aws.amazon.com/vpc/)
- [Pricing AWS EC2](https://aws.amazon.com/fr/ec2/pricing/on-demand/)

## 📝 Licence

Ce projet est libre d'utilisation.

## 👤 Auteur

Créé pour un cluster K3s de démonstration — Juin 2026