terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=3.2.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {
  tenant_id = var.tenant_id
}

# Get Microsoft Graph Service Principal
data "azuread_service_principal" "msgraph" {
  display_name = "Microsoft Graph"
}

# Define Rotating Secret
resource "time_rotating" "example" {
  rotation_days = 180
}

# Create Azure AD Application
resource "azuread_application" "example" {
  display_name     = "Entra Application"
  description      = "My Testing Entra ID application"
  sign_in_audience = "AzureADMyOrg"

  password {
    display_name = "MySecret-1"
    start_date   = timestamp()
    end_date     = timeadd(timestamp(), "4320h") # 6 months
  }
}

# Create Service Principal
resource "azuread_service_principal" "example_sp" {
  client_id = azuread_application.example.client_id # Fixed reference
}

# Assign API Permissions to Service Principal
resource "azuread_app_role_assignment" "msgraph_roles" {
  for_each            = toset(["User.Read.All", "Group.Read.All"])
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids[each.value]
  principal_object_id = azuread_service_principal.example_sp.object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Get Azure AD Domains
data "azuread_domains" "aad_domains" {}

# Create Users
resource "azuread_user" "example" {
  for_each            = toset(var.users)
  user_principal_name = "${each.value}@${data.azuread_domains.aad_domains.domains.0.domain_name}"
  display_name        = each.value
  password            = "Password1234!"
}

# Get Current Client Configuration
data "azuread_client_config" "current" {}

# Create Groups
resource "azuread_group" "groups" {
  for_each = toset(var.groups)

  display_name     = each.value
  owners           = [data.azuread_client_config.current.object_id]
  security_enabled = true
}

# Assign Users to Groups (2 users per group)
resource "azuread_group_member" "group_members" {
  for_each = { for idx, user in var.users : idx => user if idx < length(var.groups) * 2 }

  group_object_id  = azuread_group.groups[element(var.groups, floor(each.key / 2))].id
  member_object_id = azuread_user.example[each.value].id
}

# Get Resource Group
data "azurerm_resource_group" "tf_backend" {
  name = var.resource_group_name
}

# Get Azure Container Registry
data "azurerm_container_registry" "acr" {
  name                = "consultomer"
  resource_group_name = data.azurerm_resource_group.tf_backend.name
}

# Create User-Assigned Identity for ACR Access
resource "azurerm_user_assigned_identity" "acr_identity" {
  resource_group_name = data.azurerm_resource_group.tf_backend.name
  location            = data.azurerm_resource_group.tf_backend.location
  name                = "muid-acr"
}

# Assign ACR Pull Role to Identity
resource "azurerm_role_assignment" "acr_pull" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.acr_identity.principal_id
}

# Output Secret (for debugging)
output "example_password" {
  sensitive = true
  value     = tolist(azuread_application.example.password).0.value
}
