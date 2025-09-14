#!/usr/bin/env python3
"""
Network Configuration for VM-3 (LLM Adapter)
Real network topology and connectivity information
"""

# VM-3 自身網路配置
VM3_CONFIG = {
    "hostname": "VM-3",
    "role": "LLM Adapter / Intent Service",
    "external_ip": "147.251.115.156",  # 外部訪問 (SSH)
    "interfaces": {
        "ens3": {
            "network": "internal-ipv4-general-private",
            "ip": "172.16.2.10",
            "subnet": "172.16.0.0/16",
            "description": "Internal private network shared with all VMs"
        },
        "ens4": {
            "network": "group-project-network",
            "ip": "192.168.0.201",
            "subnet": "192.168.0.0/24",
            "description": "Project network for VM communication"
        }
    },
    "service": {
        "name": "LLM Intent Adapter",
        "port": 8888,
        "bind": "0.0.0.0",  # Listen on all interfaces
        "endpoints": {
            "health": "/health",
            "generate_intent": "/generate_intent"
        }
    }
}

# 其他 VM 網路配置
VM_NETWORK_MAP = {
    "VM-1": {
        "hostname": "VM-1",
        "role": "Nephio / Intent Gateway",
        "external_ip": "147.251.115.143",
        "group_project_network": "192.168.0.47",  # 優先使用此網路與 VM-3 通信
        "internal_ipv4": "172.16.0.78",
        "connectivity_to_vm3": {
            "preferred": "192.168.0.47 -> 192.168.0.201",  # Via group-project-network
            "alternative": "172.16.0.78 -> 172.16.2.10"    # Via internal-ipv4
        }
    },
    "VM-2": {
        "hostname": "VM-2",
        "role": "Unknown/TBD",
        "external_ip": "147.251.115.129",
        "group_project_network": "192.168.0.174",
        "internal_ipv4": "172.16.4.45",
        "connectivity_to_vm3": {
            "preferred": "192.168.0.174 -> 192.168.0.201",
            "alternative": "172.16.4.45 -> 172.16.2.10"
        }
    },
    "VM-4": {
        "hostname": "VM-4",
        "role": "Edge2",
        "external_ip": "147.251.115.193",
        "external_ipv6": "2001:718:801:43b:f816:3eff:fe3e:cb45",
        "internal_ipv4": "172.16.0.89",
        "group_project_network": None,  # 重要：VM-4 沒有 group-project-network
        "connectivity_to_vm3": {
            "only": "172.16.0.89 -> 172.16.2.10"  # 只能通過 internal-ipv4
        }
    }
}

# 服務發現配置
SERVICE_URLS = {
    "from_vm1": {
        "llm_adapter": "http://192.168.0.201:8888",  # VM-1 應使用此 URL
        "description": "VM-1 connects via group-project-network"
    },
    "from_vm2": {
        "llm_adapter": "http://192.168.0.201:8888",
        "description": "VM-2 connects via group-project-network"
    },
    "from_vm4": {
        "llm_adapter": "http://172.16.2.10:8888",  # VM-4 必須使用 internal-ipv4
        "description": "VM-4 only has internal-ipv4 connectivity"
    },
    "from_external": {
        "ssh": "ssh ubuntu@147.251.115.156",
        "description": "External SSH access only"
    }
}

# Target Site 映射到實際 VM
TARGET_SITE_MAPPING = {
    "edge1": {
        "vm": "VM-1",
        "description": "Primary edge site (Nephio)",
        "network_access": "192.168.0.47 or 172.16.0.78"
    },
    "edge2": {
        "vm": "VM-4",
        "description": "Secondary edge site",
        "network_access": "172.16.0.89 (internal-ipv4 only)"
    },
    "both": {
        "vms": ["VM-1", "VM-4"],
        "description": "Deploy to both edge sites"
    }
}

def get_service_url_for_vm(source_vm: str) -> str:
    """
    獲取特定 VM 應該使用的 LLM Adapter URL

    Args:
        source_vm: 來源 VM 名稱 (VM-1, VM-2, VM-4)

    Returns:
        適合該 VM 使用的服務 URL
    """
    key = f"from_{source_vm.lower().replace('-', '')}"
    if key in SERVICE_URLS:
        return SERVICE_URLS[key]["llm_adapter"]
    return None

def get_vm_connectivity(vm_name: str) -> dict:
    """
    獲取指定 VM 的連接資訊

    Args:
        vm_name: VM 名稱 (VM-1, VM-2, VM-3, VM-4)

    Returns:
        VM 的網路配置資訊
    """
    if vm_name == "VM-3":
        return VM3_CONFIG
    return VM_NETWORK_MAP.get(vm_name, {})

# 測試連通性指令
TEST_COMMANDS = {
    "from_vm1": [
        "ping 192.168.0.201",
        "curl http://192.168.0.201:8888/health"
    ],
    "from_vm4": [
        "ping 172.16.2.10",
        "curl http://172.16.2.10:8888/health"
    ],
    "local": [
        "netstat -tlnp | grep 8888",
        "curl http://localhost:8888/health"
    ]
}

if __name__ == "__main__":
    print("=== VM-3 Network Configuration ===")
    print(f"External IP: {VM3_CONFIG['external_ip']}")
    print(f"Group Project Network: {VM3_CONFIG['interfaces']['ens4']['ip']}")
    print(f"Internal IPv4: {VM3_CONFIG['interfaces']['ens3']['ip']}")
    print(f"Service Port: {VM3_CONFIG['service']['port']}")
    print("\n=== Service URLs for Other VMs ===")
    for vm, config in SERVICE_URLS.items():
        if 'llm_adapter' in config:
            print(f"{vm}: {config['llm_adapter']}")