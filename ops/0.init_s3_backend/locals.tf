locals {
  project_name = "aismc"
  service_name = "platform-terraformstatefile-20251101"
  environment  = "ops"

  bucket_name =  "${local.project_name}-${local.service_name}-061100493617"

  tags ={
    Project = local.project_name
    Service = local.service_name
    Environment = local.environment
  }
}

