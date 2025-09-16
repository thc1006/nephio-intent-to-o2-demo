#!/usr/bin/env python3
"""Simple converter wrapper for TMF921 to 3GPP TS 28.312"""

import json
import sys
from tmf921_to_28312.converter import TMF921To28312Converter

def main():
    # Read input from stdin
    input_data = sys.stdin.read()

    try:
        tmf921_intent = json.loads(input_data)
        converter = TMF921To28312Converter()

        # Convert TMF921 to 3GPP TS 28.312
        result = converter.convert(tmf921_intent)

        # Extract the expectation from the result
        if hasattr(result, 'expectation'):
            output = result.expectation
        elif hasattr(result, '__dict__'):
            output = result.__dict__
        else:
            output = {"expectation": str(result)}

        # Output the result
        print(json.dumps(output, indent=2))

    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()