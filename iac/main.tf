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

resource "azuread_application" "example" {
  display_name = "example"
  owners       = [data.azuread_client_config.current.object_id]

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
