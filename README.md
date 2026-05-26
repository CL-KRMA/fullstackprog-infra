# Cluster K3s sur AWS avec Terraform

Ce projet Terraform configure une infrastructure complète pour déployer un cluster Kubernetes K3s haute disponibilité sur AWS.

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
- **1 nœud Master** (contrôleur)
- **2 nœuds Worker** (calcul)

Tous les nœuds utilisent des instances EC2 **t3.medium** avec **20 GB** de stockage SSD (gp3) et bénéficient d'adresses IP publiques élastiques.

### En clair, ce code fait quoi ?

**Simplement : il crée automatiquement 3 serveurs dans le cloud AWS prêts à fonctionner ensemble comme un cluster Kubernetes.**

À l'exécution, le code :
1. **Crée un réseau privé** (VPC) pour que les 3 serveurs communiquent entre eux
2. **Crée 3 serveurs Ubuntu** avec chacun 20 GB de disque
3. **Configure les règles de sécurité** pour autoriser le trafic nécessaire (SSH, ports Kubernetes, etc.)
4. **Ajoute une clé SSH** pour pouvoir se connecter en ligne de commande
5. **Assigne des adresses IP publiques** pour accéder aux serveurs depuis internet

Une fois déployé, tu peux installer Kubernetes sur ces 3 serveurs et lancer des applications en conteneurs.

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│        VPC (192.168.2.0/24)             │
├─────────────────────────────────────────┤
│  ┌──────────────────────────────────┐   │
│  │  Subnet (us-east-1a)             │   │
│  │  192.168.2.0/24                  │   │
│  ├──────────────────────────────────┤   │
│  │ Master (192.168.2.10)            │   │
│  │ Worker1 (192.168.2.11)           │   │
│  │ Worker2 (192.168.2.12)           │   │
│  └──────────────────────────────────┘   │
│                                          │
│  Internet Gateway (IGW)                  │
│  Route Table (0.0.0.0/0 → IGW)          │
│  Security Group (K3s ports)              │
└─────────────────────────────────────────┘
```

## 📦 Prérequis

### Outils nécessaires

- **Terraform** >= 1.0 ([Installation](https://www.terraform.io/downloads.html))
- **AWS CLI** >= 2.0 ([Installation](https://aws.amazon.com/fr/cli/))
- **Compte AWS** avec permissions suffisantes
- **Clé SSH** (sera générée ou utilisée)

### Permissions AWS requises

Votre utilisateur AWS doit avoir accès à :
- EC2 (instances, security groups, key pairs)
- VPC (VPC, subnets, internet gateways, route tables)
- Elastic IPs

## 🚀 Installation

### 1. Cloner ou télécharger le projet

```bash
https://github.com/CL-KRMA/aws-terraform-config
```

### 2. Générer une clé SSH (si nécessaire)

Si vous n'avez pas déjà de clé SSH :

```bash
ssh-keygen -t rsa -b 4096 -f keys/ma-cle-ssh -N ""
```

Cette commande crée :
- `keys/ma-cle-ssh` (clé privée)
- `keys/ma-cle-ssh.pub` (clé publique)

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

### Variables (optionnelles)

Vous pouvez modifier les paramètres dans `main.tf` :

| Paramètre | Valeur actuelle | Description |
|-----------|-----------------|-------------|
| Region | `us-east-1` | Région AWS |
| VPC CIDR | `192.168.2.0/24` | Bloc réseau du VPC |
| Instance Type | `t3.medium` | Type d'instance EC2 |
| Volume Size | `20` | Taille du disque en GB |
| Volume Type | `gp3` | Type de stockage (SSD performant) |
| Master IP | `192.168.2.10` | IP privée du master |
| Worker1 IP | `192.168.2.11` | IP privée du worker 1 |
| Worker2 IP | `192.168.2.12` | IP privée du worker 2 |

## 🎬 Déploiement

### Étape 1 : Initialiser Terraform

```bash
terraform init
```

Cela télécharge les providers AWS et initialise le répertoire `.terraform`.

### Étape 2 : Planifier le déploiement

```bash
terraform plan -out=tfplan
```

Cela affiche toutes les ressources qui seront créées. Vérifiez que tout est correct.

### Étape 3 : Appliquer la configuration

```bash
terraform apply tfplan
```

Cela crée toutes les ressources sur AWS. **Comptez 5-10 minutes** pour que tout soit opérationnel.

### Étape 4 : Récupérer les adresses IP

Après le déploiement, les adresses IP publiques apparaissent. Vous pouvez les afficher avec :

```bash
terraform output
```

Ou dans la console AWS EC2.

## 🔌 Accès au cluster

### Connexion SSH aux nœuds

```bash
# Master
ssh -i keys/ma-cle-ssh ubuntu@<MASTER_PUBLIC_IP>

# Worker 1
ssh -i keys/ma-cle-ssh ubuntu@<WORKER1_PUBLIC_IP>

# Worker 2
ssh -i keys/ma-cle-ssh ubuntu@<WORKER2_PUBLIC_IP>
```

Remplacez `<MASTER_PUBLIC_IP>`, etc., par les IPs publiques réelles.

### Installation de K3s

Une fois connecté au master :

```bash
curl -sfL https://get.k3s.io | sh -
```

Sur les workers :

```bash
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 \
  K3S_TOKEN=<TOKEN> sh -
```

Récupérez le token depuis le master :

```bash
cat /var/lib/rancher/k3s/server/node-token
```

## 📦 Ressources créées

### Réseau
- **VPC** : `aws_vpc.main`
- **Subnet** : `aws_subnet.main_subnet`
- **Internet Gateway** : `aws_internet_gateway.main_gw`
- **Route Table** : `aws_route_table.public_rt`
- **Association RT-Subnet** : `aws_route_table_association.main_assoc`

### Sécurité
- **Security Group** : `aws_security_group.k3s_sg`
  - SSH (22)
  - ICMP (ping)
  - K3s API (6443)
  - K3s VXLAN (8472/UDP)
  - Kubelet (10250)
  - NodePorts (30000-32767)
  - HTTP/HTTPS (80, 443)

### Calcul
- **Key Pair** : `aws_key_pair.my_key`
- **Master** : `aws_instance.ubuntu_vps1`
  - Type : t3.medium
  - IP privée : 192.168.2.10
  - IP élastique : `aws_eip.vps1_ip`

- **Worker 1** : `aws_instance.ubuntu_vps2`
  - Type : t3.medium
  - IP privée : 192.168.2.11
  - IP élastique : `aws_eip.vps2_ip`

- **Worker 2** : `aws_instance.ubuntu_vps3`
  - Type : t3.medium
  - IP privée : 192.168.2.12
  - IP élastique : `aws_eip.vps3_ip`

## 🔧 Maintenance

### Voir l'état actuel

```bash
terraform show
```

### Modifier une ressource

1. Éditez `main.tf`
2. Exécutez `terraform plan`
3. Vérifiez les changements
4. Exécutez `terraform apply`

### Sauvegarder l'état

L'état Terraform est sauvegardé dans `terraform.tfstate` et `terraform.tfstate.backup`. 

**Ne modifiez pas ces fichiers directement.**

## 🗑️ Nettoyage

Pour détruire toutes les ressources et éviter les frais AWS :

```bash
terraform destroy
```

Confirmez en tapant `yes` quand demandé.

## 📊 Coûts estimés

| Ressource | Quantité | Coût/mois |
|-----------|----------|-----------|
| t3.medium (on-demand) | 3 | ~$120 |
| EIP (si attachée) | 3 | $0 |
| **Total** | | **~$120** |

*Les coûts varient selon la région et les promotions AWS.*

## 🐛 Dépannage

### "Terraform not found"
Installez Terraform : https://www.terraform.io/downloads.html

### "AWS credentials not found"
Exécutez `aws configure` avec vos clés d'accès.

### "Permission denied (publickey)"
Vérifiez que le fichier `keys/ma-cle-ssh` existe et a les bonnes permissions (600).

### Les instances mettent longtemps à démarrer
C'est normal, AWS a besoin de 5-10 minutes pour initialiser les ressources.

## 📚 Ressources

- [Documentation Terraform AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentation K3s](https://docs.k3s.io/)
- [Documentation AWS VPC](https://docs.aws.amazon.com/vpc/)
- [Pricing AWS EC2](https://aws.amazon.com/fr/ec2/pricing/on-demand/)

## 📝 License

Ce projet est libre d'utilisation.

## 👤 Auteur

Créé pour un cluster K3s de démonstration - Mai 2026
