#!/usr/bin/env python3
"""
Port Herald Helper Script
Provides additional utilities for working with Port Herald
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path

def get_db_path():
    """Get the database path from command line or default"""
    return Path.home() / ".port-herald" / "port-herald.db"

def export_hosts_csv(db_path, output_file):
    """Export all hosts to CSV"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT ip_address, hostname, mac_address, os, status, first_seen, last_seen
        FROM hosts
        ORDER BY ip_address
    """)
    
    with open(output_file, 'w') as f:
        f.write("IP Address,Hostname,MAC Address,OS,Status,First Seen,Last Seen\n")
        for row in cursor.fetchall():
            f.write(','.join(str(x) if x else '' for x in row) + '\n')
    
    conn.close()
    print(f"✅ Exported {cursor.rowcount} hosts to {output_file}")

def export_open_ports_csv(db_path, output_file):
    """Export all open ports to CSV"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT h.ip_address, p.port_number, p.protocol, p.service, p.product, p.version
        FROM hosts h
        JOIN ports p ON h.id = p.host_id
        WHERE p.state = 'open'
        ORDER BY h.ip_address, p.port_number
    """)
    
    with open(output_file, 'w') as f:
        f.write("IP Address,Port,Protocol,Service,Product,Version\n")
        for row in cursor.fetchall():
            f.write(','.join(str(x) if x else '' for x in row) + '\n')
    
    conn.close()
    print(f"✅ Exported {cursor.rowcount} open ports to {output_file}")

def statistics(db_path):
    """Show database statistics"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Total hosts
    cursor.execute("SELECT COUNT(*) FROM hosts")
    total_hosts = cursor.fetchone()[0]
    
    # Hosts up
    cursor.execute("SELECT COUNT(*) FROM hosts WHERE status = 'up'")
    hosts_up = cursor.fetchone()[0]
    
    # Total open ports
    cursor.execute("SELECT COUNT(*) FROM ports WHERE state = 'open'")
    open_ports = cursor.fetchone()[0]
    
    # Networks
    cursor.execute("SELECT COUNT(*) FROM networks")
    networks = cursor.fetchone()[0]
    
    # Recent scans
    cursor.execute("SELECT COUNT(*) FROM scans")
    scans = cursor.fetchone()[0]
    
    # Top services
    cursor.execute("""
        SELECT service, COUNT(*) as count
        FROM ports
        WHERE state = 'open' AND service IS NOT NULL
        GROUP BY service
        ORDER BY count DESC
        LIMIT 10
    """)
    top_services = cursor.fetchall()
    
    print("=" * 50)
    print("  Port Herald Database Statistics")
    print("=" * 50)
    print(f"\nTotal Hosts:      {total_hosts}")
    print(f"Hosts Up:         {hosts_up}")
    print(f"Open Ports:       {open_ports}")
    print(f"Networks:         {networks}")
    print(f"Total Scans:      {scans}")
    print(f"\nTop Services:")
    for service, count in top_services:
        print(f"  {service:20s} {count:5d}")
    print()
    
    conn.close()

def find_hosts_by_port(db_path, port_number):
    """Find all hosts with a specific port open"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT h.ip_address, h.hostname, p.service, p.product, p.version
        FROM hosts h
        JOIN ports p ON h.id = p.host_id
        WHERE p.port_number = ? AND p.state = 'open'
        ORDER BY h.ip_address
    """, (port_number,))
    
    results = cursor.fetchall()
    
    if results:
        print(f"\n🎯 Hosts with port {port_number} open:\n")
        for ip, hostname, service, product, version in results:
            hostname_str = f" ({hostname})" if hostname else ""
            service_str = service or "unknown"
            product_str = f" - {product}" if product else ""
            version_str = f" {version}" if version else ""
            print(f"  {ip}{hostname_str}")
            print(f"    Service: {service_str}{product_str}{version_str}")
    else:
        print(f"\n❌ No hosts found with port {port_number} open")
    
    print()
    conn.close()

def find_hosts_by_service(db_path, service_name):
    """Find all hosts running a specific service"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT h.ip_address, h.hostname, p.port_number, p.product, p.version
        FROM hosts h
        JOIN ports p ON h.id = p.host_id
        WHERE p.service LIKE ? AND p.state = 'open'
        ORDER BY h.ip_address, p.port_number
    """, (f"%{service_name}%",))
    
    results = cursor.fetchall()
    
    if results:
        print(f"\n🎯 Hosts running '{service_name}':\n")
        for ip, hostname, port, product, version in results:
            hostname_str = f" ({hostname})" if hostname else ""
            product_str = f" - {product}" if product else ""
            version_str = f" {version}" if version else ""
            print(f"  {ip}{hostname_str} - Port {port}{product_str}{version_str}")
    else:
        print(f"\n❌ No hosts found running '{service_name}'")
    
    print()
    conn.close()

def list_networks(db_path):
    """List all discovered networks"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT n.cidr, COUNT(h.id) as host_count
        FROM networks n
        LEFT JOIN hosts h ON n.id = h.network_id
        GROUP BY n.id
        ORDER BY n.cidr
    """)
    
    results = cursor.fetchall()
    
    if results:
        print("\n📡 Discovered Networks:\n")
        for cidr, count in results:
            print(f"  {cidr:20s} {count:3d} hosts")
    else:
        print("\n❌ No networks found")
    
    print()
    conn.close()

def main():
    parser = argparse.ArgumentParser(
        description="Port Herald Helper Utilities",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Show statistics
  %(prog)s stats
  
  # Export data
  %(prog)s export-hosts hosts.csv
  %(prog)s export-ports ports.csv
  
  # Find hosts
  %(prog)s find-port 22
  %(prog)s find-service ssh
  
  # List networks
  %(prog)s networks
        """
    )
    
    parser.add_argument('--database', default=None, help='Database path (default: ~/.port-herald/port-herald.db)')
    
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Statistics
    subparsers.add_parser('stats', help='Show database statistics')
    
    # Export commands
    export_hosts_parser = subparsers.add_parser('export-hosts', help='Export hosts to CSV')
    export_hosts_parser.add_argument('output', help='Output CSV file')
    
    export_ports_parser = subparsers.add_parser('export-ports', help='Export open ports to CSV')
    export_ports_parser.add_argument('output', help='Output CSV file')
    
    # Find commands
    find_port_parser = subparsers.add_parser('find-port', help='Find hosts with specific port open')
    find_port_parser.add_argument('port', type=int, help='Port number')
    
    find_service_parser = subparsers.add_parser('find-service', help='Find hosts running specific service')
    find_service_parser.add_argument('service', help='Service name (e.g., ssh, http)')
    
    # Networks
    subparsers.add_parser('networks', help='List all networks')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    db_path = args.database or get_db_path()
    
    if not Path(db_path).exists():
        print(f"❌ Database not found: {db_path}")
        print("Make sure Port Herald has been run at least once.")
        sys.exit(1)
    
    if args.command == 'stats':
        statistics(db_path)
    elif args.command == 'export-hosts':
        export_hosts_csv(db_path, args.output)
    elif args.command == 'export-ports':
        export_open_ports_csv(db_path, args.output)
    elif args.command == 'find-port':
        find_hosts_by_port(db_path, args.port)
    elif args.command == 'find-service':
        find_hosts_by_service(db_path, args.service)
    elif args.command == 'networks':
        list_networks(db_path)

if __name__ == '__main__':
    main()
