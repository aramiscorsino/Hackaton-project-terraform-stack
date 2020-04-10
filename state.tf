terraform {
  backend "s3" {
    bucket = "hackathon-fiap-1dvp-rm334757"
    key    = "state/hackaton-cicd-deploy"
    region = "us-east-1"
  }
}