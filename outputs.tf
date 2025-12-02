output "fe_dns_name" {
  value = aws_route53_record.private_star_rocks_dns.fqdn
}

output "grafana_address" {
  value = aws_instance.star_rocks_grafana.private_ip
}