variable "deployer_usernames" {
  description = "Names of IAM users (created in the aws repo) to add to the wardtalks-deployers group"
  type        = list(string)
  default     = ["brian"]
}
