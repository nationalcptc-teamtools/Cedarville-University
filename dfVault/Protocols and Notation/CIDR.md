CIDR (Classless Inter-Domain Routing) is a method for allocating IP address ranges and representing network prefixes, which allows for computer routing, describing address blocks, route aggregation (allowing one route to represent multiple networks), and subnetting.

CIDR uses the notation IP_ADDRESS/x, where x is a number between 0 and 32.

/x is the the network prefix length, where x specifies the number of network bits, which identify the subnet.

The remainder of the bits in the IP address are the host bits, which can vary. Each of these host bit combinations represents an IP address.

The number of addresses within a block is calculable from 2^(32 - x).

CIDR also defines the subnet mask, which separates an IP address into the network and host bits.

CIDR allows for more flexibility with prefix length, which makes routing much more efficient.