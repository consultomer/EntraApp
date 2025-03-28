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

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]
}
resource "time_rotating" "example" {
  rotation_days = 180
}
resource "azuread_application" "example" {
  display_name     = "Entra Application"
  description      = "My Testing entraid application"
  sign_in_audience = "AzureADMyOrg"
  password {
    display_name = "MySecret-1"
    start_date   = time_rotating.example.id
    end_date     = timeadd(time_rotating.example.id, "4320h")
  }
}

output "example_password" {
  sensitive = true
  value     = tolist(azuread_application.example.password).0.value
}

resource "azuread_application_api_access" "example_msgraph" {
  application_id = azuread_application.example.id
  api_client_id  = data.azuread_application_published_app_ids.well_known.result["MicrosoftGraph"]

  role_ids = [
    data.azuread_service_principal.msgraph.app_role_ids["Group.Read.All"],
    data.azuread_service_principal.msgraph.app_role_ids["User.Read.All"],
  ]

  scope_ids = [
    data.azuread_service_principal.msgraph.oauth2_permission_scope_ids["User.ReadWrite"],
  ]
}

data "azuread_domains" "aad_domains" {}
# Create a user
resource "azuread_user" "example" {
  for_each            = toset(var.users)
  user_principal_name = "${each.value}@${data.azuread_domains.aad_domains.domains.0.domain_name}"
  display_name        = each.value
  password            = "Password1234!"
}
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
  for_each = {
    for idx, user in var.users : idx => user
    if idx < length(var.groups) * 2 # Ensure only 2 users per group
  }

  group_object_id  = azuread_group.groups[element(var.groups, floor(each.key / 2))].id
  member_object_id = azuread_user.users[each.value].id
}

# Resource Group
data "azurerm_resource_group" "tf_backend" {
  name = var.resource_group_name
}
data "azurerm_container_registry" "acr" {
  name                = "consultomer"
  resource_group_name = data.azurerm_resource_group.tf_backend.name
}
# User-Assigned Identity for ACR Access
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
