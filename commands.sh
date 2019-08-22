# Start Byfn newtork

git clone https://github.com/hyperledger/fabric-samples.git
cd fabric-samples
git checkout v1.4.2

# Fetch bootstrap.sh from fabric repository using
curl -sS https://raw.githubusercontent.com/hyperledger/fabric/master/scripts/bootstrap.sh -o ./scripts/bootstrap.sh
# Change file mode to executable
chmod +x ./scripts/bootstrap.sh
# Download binaries and docker images
./scripts/bootstrap.sh 1.4.2

cd first-network

echo Y | bash byfn.sh -m generate -o kafka
echo Y | bash byfn.sh -m up -o kafka

# Check orderer logs

docker logs orderer.example.com

#
# Enable Maintenance MODE
#

# Login to cli container
docker exec -ti cli bash

# Determine channel names, peer has joined. We will need to modify all of those channels plus a system one.
peer channel list

# Steps to setup maintenance mode
export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CHANNEL_NAME=mychannel

mkdir maintenance_on_$CHANNEL_NAME && cd maintenance_on_$CHANNEL_NAME

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

cp config.json config_mod.json

### MANUAL STEPS!
cat config.json | grep name


sed -i 's/NORMAL/MAINTENANCE/g' config_mod.json
configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input config_mod.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output config_update.pb
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate | jq . > config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_envelope.json
configtxlator proto_encode --input config_update_envelope.json --type common.Envelope --output config_update_in_envelope.pb
peer channel signconfigtx -f config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel update -f config_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA

# Put system channel into maintenance mode

export CHANNEL_NAME=byfn-sys-channel
cd ..

mkdir maintenance_on_$CHANNEL_NAME && cd maintenance_on_$CHANNEL_NAME

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

cp config.json config_mod.json
cat config.json | grep name
sed -i 's/NORMAL/MAINTENANCE/g' config_mod.json
configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input config_mod.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output config_update.pb
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate | jq . > config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"byfn-sys-channel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_envelope.json
configtxlator proto_encode --input config_update_envelope.json --type common.Envelope --output config_update_in_envelope.pb
peer channel signconfigtx -f config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel update -f config_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA

exit

# Restart network containers

docker restart $(docker ps -a | grep "hyperledger/fabric" | awk '{print $1}')

#
# Switch from kafka to raft
#

docker exec -ti cli bash

export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CHANNEL_NAME=mychannel

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

mkdir switch_to_raft_${CHANNEL_NAME} && cd switch_to_raft_${CHANNEL_NAME}

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
cp config.json config_mod.json

### MANUAL STEPS!
### Perform migration to etcdraft here for all needed channels

# Get server certificate
base64 /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt -w0 && echo ""

# Perform json modifications, manually !!

configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input config_mod.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output config_update.pb
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate | jq . > config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_envelope.json
configtxlator proto_encode --input config_update_envelope.json --type common.Envelope --output config_update_in_envelope.pb
peer channel signconfigtx -f config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel update -f config_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA

### Perform migration to etcdraft for system channel

export CHANNEL_NAME=byfn-sys-channel
cd ..

mkdir switch_to_raft_${CHANNEL_NAME} && cd switch_to_raft_${CHANNEL_NAME}

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
cp config.json config_mod.json

### MANUAL STEPS!
### Perform migration to etcdraft here for all needed channels

# Get server certificate
base64 /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt -w0 && echo ""

# Perform json modifications, manually !!

configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input config_mod.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output config_update.pb
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate | jq . > config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"byfn-sys-channel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_envelope.json
configtxlator proto_encode --input config_update_envelope.json --type common.Envelope --output config_update_in_envelope.pb
peer channel signconfigtx -f config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel update -f config_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA

exit 

# Restart all the containers

docker restart $(docker ps -a | grep "hyperledger/fabric" | awk '{print $1}')

# Make sure that orderer successfully started in raft mode
docker logs orderer.example.com

### 
# Switch back from maintenance mode
###

# Login to cli container
docker exec -ti cli bash

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CHANNEL_NAME=mychannel

mkdir maintenance_off_$CHANNEL_NAME && cd maintenance_off_$CHANNEL_NAME

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

cp config.json config_mod.json

sed -i 's/MAINTENANCE/NORMAL/g' config_mod.json
configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input config_mod.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output config_update.pb
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate | jq . > config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"mychannel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_envelope.json
configtxlator proto_encode --input config_update_envelope.json --type common.Envelope --output config_update_in_envelope.pb
peer channel signconfigtx -f config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel update -f config_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA

# Put system channel from maintenance mode back

export CHANNEL_NAME=byfn-sys-channel
cd ..

mkdir maintenance_on_$CHANNEL_NAME && cd maintenance_on_$CHANNEL_NAME

peer channel fetch config config_block.pb -o orderer.example.com:7050 -c $CHANNEL_NAME --tls --cafile $ORDERER_CA

configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json

cp config.json config_mod.json

sed -i 's/MAINTENANCE/NORMAL/g' config_mod.json
configtxlator proto_encode --input config.json --type common.Config --output config.pb
configtxlator proto_encode --input config_mod.json --type common.Config --output modified_config.pb
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output config_update.pb
configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate | jq . > config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"byfn-sys-channel", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_envelope.json
configtxlator proto_encode --input config_update_envelope.json --type common.Envelope --output config_update_in_envelope.pb
peer channel signconfigtx -f config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp/
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel update -f config_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA

exit

# Restart network containers

docker restart $(docker ps -a | grep "hyperledger/fabric" | awk '{print $1}')

# Test if network actually operates, by invoking your chaincode

# Login to cli container
docker exec -ti cli bash

export ORDERER_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export CHANNEL_NAME=mychannel
export PEER0_ORG1_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt

peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n mycc --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles $PEER0_ORG1_CA --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles $PEER0_ORG2_CA -c '{"Args":["invoke","a","b","10"]}' --tls --cafile $ORDERER_CA

peer chaincode invoke -o orderer.example.com:7050 -C $CHANNEL_NAME -n mycc --peerAddresses peer0.org1.example.com:7051 --tlsRootCertFiles $PEER0_ORG1_CA --peerAddresses peer0.org2.example.com:9051 --tlsRootCertFiles $PEER0_ORG2_CA -c '{"Args":["query","a"]}' --tls --cafile $ORDERER_CA
