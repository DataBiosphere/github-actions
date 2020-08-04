#
# IP/DNS Outputs
#
output "ingress_ips" {
  value       = module.env.ingress_ips
  description = "Service ingress IPs"
}
output "fqdns" {
  value       = module.env.fqdns
  description = "Service fully qualified domain names"
}
output "versions" {
  value       = module.env.versions
  description = "Base64 encoded JSON string of version overrides"
}
