data "aws_default_tags" "vars" {}

locals {
  prefix = "${data.aws_default_tags.vars.tags.Environment}-${data.aws_default_tags.vars.tags.Project}"
}
