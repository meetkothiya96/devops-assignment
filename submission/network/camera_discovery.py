#!/usr/bin/env python3
"""
camera_discovery.py — ONVIF Camera Discovery Tool

TASK: Implement a camera discovery script that:
  1. Reads an ONVIF WS-Discovery XML response (like data/onvif_mock_response.xml)
  2. Parses the XML to extract camera information
  3. Outputs a JSON array of discovered cameras
  4. Handles timeouts and malformed XML gracefully

Requirements:
  - Parse the ONVIF ProbeMatch elements
  - Extract: endpoint address (UUID), hardware model, name, location, service URL
  - Output valid JSON to stdout
  - Accept --input flag for XML file path (default: stdin)
  - Accept --timeout flag for discovery timeout in seconds
  - Handle errors gracefully (timeout, parse errors, missing fields)

Example output:
[
  {
    "uuid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "model": "P3265-LVE",
    "name": "AXIS P3265-LVE",
    "location": "LoadingDockA",
    "service_url": "http://10.50.20.101:80/onvif/device_service",
    "ip": "10.50.20.101"
  }
]
"""

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from urllib.parse import urlparse


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description="ONVIF camera discovery tool")
    parser.add_argument("--input", type=str, help="Path to XML file (default: stdin)")
    parser.add_argument("--timeout", type=int, default=5, help="Discovery timeout in seconds")
    return parser.parse_args()


def parse_onvif_response(xml_content):
    """Parse ONVIF WS-Discovery XML and return list of camera dicts."""
    namespaces = {
        'd': 'http://schemas.xmlsoap.org/ws/2005/04/discovery',
        'soap': 'http://www.w3.org/2003/05/soap-envelope'
    }
    
    cameras = []
    
    try:
        root = ET.fromstring(xml_content)
        matches = root.findall('.//d:ProbeMatch', namespaces)
        
        for match in matches:
            camera = {}
            
            # Extract UUID
            addr = match.find('.//d:Address', namespaces)
            if addr is not None and addr.text:
                uuid = addr.text.replace('urn:uuid:', '')
                camera['uuid'] = uuid
            
            # Extract scopes (model, name, location)
            scopes = match.find('.//d:Scopes', namespaces)
            if scopes is not None and scopes.text:
                for scope in scopes.text.split():
                    if '/hardware/' in scope:
                        camera['model'] = scope.split('/hardware/')[-1]
                    elif '/name/' in scope:
                        camera['name'] = scope.split('/name/')[-1].replace('%20', ' ')
                    elif '/location/' in scope:
                        camera['location'] = scope.split('/location/')[-1]
            
            # Extract service URL and IP
            xaddrs = match.find('.//d:XAddrs', namespaces)
            if xaddrs is not None and xaddrs.text:
                service_url = xaddrs.text.strip()
                camera['service_url'] = service_url
                parsed = urlparse(service_url)
                camera['ip'] = parsed.hostname
            
            if camera:
                cameras.append(camera)
                
    except ET.ParseError as e:
        print(f"Error parsing XML: {e}", file=sys.stderr)
        sys.exit(1)
    
    return cameras


def main():
    args = parse_args()
    
    try:
        if args.input:
            with open(args.input, 'r') as f:
                xml_content = f.read()
        else:
            xml_content = sys.stdin.read()
        
        cameras = parse_onvif_response(xml_content)
        print(json.dumps(cameras, indent=2))
        
    except FileNotFoundError:
        print(f"Error: File '{args.input}' not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
