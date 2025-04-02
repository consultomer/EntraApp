# PlexInformer Project

## Table of Contents
- [Introduction](#introduction)
- [Features](#features)
- [Technologies Used](#technologies-used)
- [Prerequisite](#prerequisite)
- [Deployment](#deployment)
  - [Locally Deployment](#locally-deployment)
  - [To Use Github Action](#to-use-github-action)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Introduction

This Project is an automated infrastructure deployment and application hosting solution using Terraform, Azure Container Apps, Azure Active Directory (AAD), and GitHub Actions. This project enables seamless deployment of a Flask-based application within a containerized environment while integrating with Microsoft Entra ID (Azure AD) for authentication and authorization.

## Features
- **Secure Authentication & Authorization:** Integrates Microsoft Entra ID (Azure AD) for user authentication.
- **Automated Infrastructure Deployment:** Uses Terraform to define, deploy, and manage Azure resources.
- **Containerized Application Hosting:** Runs the Flask application in Azure Container Apps.
- **CI/CD with GitHub Actions:** Streamlines deployment and infrastructure management through automation.

## Technologies Used
- **Application:** Python Flask
- **Infrastructure:** Terraform
- **Pipeline:** Github Action
- **Deployment:** Azure

## Prerequisite

To deploy and run this project, the following Azure resources and permissions are required:

**Resource Group:**

**Azure Container Registry (ACR):**

**Azure AD Application with API Permissions:**

Application.ReadWrite.All,
Application.ReadWrite.OwnedBy,
AppRoleAssignment.ReadWrite.All.
Domain.Read.All,
Group.ReadWrite.All,
User.Read,
User.ReadWrite.All


## Deployment

### Locally Deployment
To set up the project locally, follow these steps:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/consultomer/EntraApp.git
   cd EntraApp
2. **Create Azure Container Registry(ACR)::**
   ```bash
   Add Azure Container Registry(ACR) 
   To Variable file to variable.tf #./iac/variables.tf
3. **Add Variables:**
   ```bash
   Subscription ID #./iac/variables.tf
   Tenant ID #./iac/variables.tf
   Resource Group name  #./iac/variables.tf
4. **Verify:**
   - Azure CLI is installed
      ```bash 
      az version
      ```
   - Azure CLI is logged in 
      ```bash 
      az login
   - [**Link For Azure Setup:**](https://learn.microsoft.com/en-us/cli/azure/get-started-with-azure-cli)
5. **Run the application:**
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve
### To Use Github Action  
1. **Clone the repository:**
   ```bash
   git clone https://github.com/consultomer/EntraApp.git
   cd EntraApp
2. **Create Azure Container Registry(ACR)::**
   ```bash
   Add Azure Container Registry(ACR) 
   To Variable file to variable.tf #./iac/variables.tf
3. **Add Variables:**
   ```bash
   Subscription ID #./iac/variables.tf
   Tenant ID #./iac/variables.tf
   Resource Group name  #./iac/variables.tf
4. **Create Github Repo:**
   ```bash
   git remote remove origin
   # Create a New Private Repository on GitHub
   # Click on code and copy the link
   git remote add origin <linkcopied>
   git branch -M main
   git push -u origin main
   # Verify the Push Check if your repository is successfully pushed by visiting
5. **Add Azure Credentials and ACR name to Github repository**
   When on your github repository 
   ```bash
   - Goto Settings
   Navigate to Security
   - Click on Secrets and Variables
   - From dropdown Click on Action
   - Click on New repository secret
   Add Name ACR_NAME
   And Secret the name of Azure Container Registry(ACR)
   Add Name AZURE_CREDENTIALS
   And in Secret add AZURE CREDENTIALS 
   {
    "clientSecret": "Your-Client-Secret",
    "subscriptionId": "Your-Subscription-ID",
    "tenantId": "Your-Tenant-ID",
    "clientId": "Your-Client-ID"
   }
6. **Final Step**
   Goto Actions Tab
   - Click on your commit message
   - Click on Re-run all jobs
   From Pop-up
   - Click on Re-run all jobs


## Contributing
Contributions are welcome! Please fork the repository and create a pull request with your changes. Ensure that your code adheres to the project's coding standards and passes all tests.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact
For any questions or support, please contact:

- **Omer Abdulrehman**
- **Email:** [consultomer@gmail.com](mailto:consultomer@gmail.com)
- **LinkedIn:** [Omer Abdulrehman](https://www.linkedin.com/in/omerarehman/)