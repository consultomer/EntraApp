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
  # Use the app_role_ids from the data source
  app_role_id         = azuread_service_principal.msgraph.app_role_ids[each.value]
  principal_object_id = azuread_service_principal.example_sp.object_id
  resource_object_id  = azuread_service_principal.example_sp.object_id
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

  group_object_id  = azuread_group.groups[element(var.groups, floor(each.key / 2))].id
  member_object_id = azuread_user.example[each.value].id
}
