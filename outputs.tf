###########
# OUTPUTS #
###########

output "gateway_dns" {
  value = "${aws_instance.gateway.*.public_dns}"
}

output "master_dns" {
  value = "${aws_instance.master.*.public_dns}"
}

output "worker_dns" {
  value = "${aws_instance.worker.*.public_dns}"
}
