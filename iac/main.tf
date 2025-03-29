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

data "azuread_client_config" "current" {}

resource "time_rotating" "example" {
  rotation_days = 180
}

data "azuread_application_published_app_ids" "well_known" {}

resource "azuread_service_principal" "msgraph" {
  client_id    = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
  use_existing = true
}
resource "azuread_application" "example" {
  display_name = "example"
  owners       = [data.azuread_client_config.current.object_id]
  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.msgraph.app_role_ids["User.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = azuread_service_principal.msgraph.app_role_ids["Group.Read.All"]
      type = "Role"
    }
  }
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
# Create Service Principal
resource "azuread_service_principal" "example_sp" {
  client_id                    = azuread_application.example.client_id # Fixed reference
  app_role_assignment_required = true
  owners                       = [data.azuread_client_config.current.object_id]
}
# Assign API Permissions to Service Principal
resource "azuread_app_role_assignment" "msgraph_roles" {
  for_each = toset(["User.Read.All", "Group.Read.All"])

  app_role_id         = lookup(azuread_service_principal.msgraph.app_role_ids, each.value, null)
  principal_object_id = azuread_service_principal.example_sp.object_id
  resource_object_id  = azuread_service_principal.msgraph.object_id
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

  group_object_id  = azuread_group.groups[element(var.groups, floor(each.key / 2))].object_id
  member_object_id = azuread_user.example[each.value].object_id
}


# Resource Group
data "azurerm_resource_group" "tf_backend" {
  name = var.resource_group_name
}
data "azurerm_container_registry" "acr" {
  name                = "consultomer"
  resource_group_name = data.azurerm_resource_group.tf_backend.name
}


# Azure Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                = "cywift-container-env"
  location            = data.azurerm_resource_group.tf_backend.location
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

# Frontend Container App
resource "azurerm_container_app" "entrapp" {
  name                         = "entrapp"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = data.azurerm_resource_group.tf_backend.name
  revision_mode                = "Single"

  depends_on = [azurerm_role_assignment.acr_pull]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_identity.id]
  }

  template {
    container {
      name   = "entrapp"
      image  = "${data.azurerm_container_registry.acr.login_server}/entrapp:latest"
      cpu    = 0.5
      memory = "1Gi"
      env {
        name  = "CLIENT_ID"
        value = azuread_application.example.client_id
      }

      env {
        name  = "CLIENT_SECRET"
        value = tolist(azuread_application.example.password).0.value
      }

      env {
        name  = "TENANT_ID"
        value = var.tenant_id
      }

    }
  }
  ingress {
    external_enabled = true
    target_port      = 5030
    transport        = https
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
  registry {
    server   = data.azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.acr_identity.id
  }
}
resource "azuread_application_redirect_uris" "example_web" {
  application_id = azuread_application.example.id
  type           = "Web"

  redirect_uris = [
    "https://${azurerm_container_app.entrapp.ingress[0].fqdn}/gettoken"
  ]
  depends_on = [azurerm_container_app.entrapp]
}