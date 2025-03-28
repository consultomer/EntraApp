terraform {
  backend "azurerm" {
    resource_group_name  = "TestingTerraform"
    storage_account_name = "terraform7172" # Replace with the actual storage account name from output
    container_name       = "collectorstate"
    key                  = "entraid.tfstate"

  }
}
