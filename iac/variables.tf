variable "subscription_id" {
  type    = string
  default = "830e9ec2-6cf9-4d0a-a2ac-5a629482dd82"

}

variable "tenant_id" {
  type    = string
  default = "1300c46e-723d-4573-9514-1319455d6d34"

}

variable "users" {
  type    = list(string)
  default = ["admin", "admin2", "user1", "user2", "client", "client2"]
}

variable "groups" {
  type    = list(string)
  default = ["GroupA", "GroupB", "GroupC"]
}