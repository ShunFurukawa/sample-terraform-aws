provider "aws" {
  version = "~> 2.0"
  region = "ap-northeast-1"
  profile = "furukawa-aws-cli"
}

terraform {
  backend "s3" {
    bucket  = "sample-terraform-aws"
    key     = "sample-terraform-aws.terraform.tfstate"
    region  = "ap-northeast-1"
    profile = "furukawa-aws-cli"
  }
}
