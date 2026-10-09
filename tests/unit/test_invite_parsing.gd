extends GutTest


func test_ip_with_port() -> void:
	assert_eq(Net.parse_invite("203.0.113.5:8000", 7777), {"address": "203.0.113.5", "port": 8000})


func test_ip_without_port_uses_default() -> void:
	assert_eq(Net.parse_invite("203.0.113.5", 7777), {"address": "203.0.113.5", "port": 7777})


func test_hostname_with_port() -> void:
	assert_eq(Net.parse_invite("game.example.com:12345", 7777), {"address": "game.example.com", "port": 12345})


func test_surrounding_whitespace_is_ignored() -> void:
	assert_eq(Net.parse_invite("  203.0.113.5:7777 \n", 1), {"address": "203.0.113.5", "port": 7777})


func test_invalid_port_falls_back_to_default() -> void:
	assert_eq(Net.parse_invite("203.0.113.5:abc", 7777)["port"], 7777)
	assert_eq(Net.parse_invite("203.0.113.5:99999", 7777)["port"], 7777)


func test_empty_text_gives_empty_address() -> void:
	assert_eq(Net.parse_invite("   ", 7777)["address"], "")


func test_ipv6_is_left_intact() -> void:
	assert_eq(Net.parse_invite("::1", 7777), {"address": "::1", "port": 7777})


func test_private_ip_ranking_prefers_home_router_ranges() -> void:
	assert_eq(HostInvite._private_ip_rank("192.168.1.50"), 0)
	assert_eq(HostInvite._private_ip_rank("10.0.0.5"), 1)
	assert_eq(HostInvite._private_ip_rank("172.29.80.1"), 2)
	assert_eq(HostInvite._private_ip_rank("172.32.0.1"), -1)
	assert_eq(HostInvite._private_ip_rank("198.51.100.7"), -1)
	assert_eq(HostInvite._private_ip_rank("169.254.1.1"), -1)
