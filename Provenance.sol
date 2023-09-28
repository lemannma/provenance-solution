pragma solidity ^0.5.0;

contract Provenance{

    //base data
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    address contractOwner;
    mapping(address => household) households;
    mapping(address => bool) meterOperators; //list of all registered meter operators; check if a address is registered is just a lockup
    mapping(address => bool) Billers; //list of all registered utility providers; check if a address is registered is just a lockup
    uint lastUsedID = 0;

    constructor() public{
        lastUsedID = 0;
        contractOwner = msg.sender;
    }

    //Prosumer/ Consumer data and functions
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    struct household{
        string solarMeterID; //a base64 string to store the encypted id of the solar meter
        string netMeterID; //a base64 string to store the encypted id of the net meter

        address meterOperator;
        address Biller;
        address[] readers;

        bool isAllreadyRegistered;
    }

    function registerAsHousehold(address _meterOperator, address _Biller, string memory encryptedSolarMeterID, string memory encryptedNetMeterID) public{
        require(households[msg.sender].isAllreadyRegistered == false);
        require(meterOperators[_meterOperator] == true); //given meter operator has to be registered
        require(meterOperators[msg.sender]==false); //address is not allowed to be a meter Operator
        require(Billers[_Biller] == true); //given meter operator has to be registered
        require(Billers[msg.sender]==false); //address is not allowed to be a Biller

        //if household is a Consumer set by convention solarMeterID to "0"
        if (keccak256(abi.encodePacked(encryptedSolarMeterID)) != keccak256(abi.encodePacked(""))) {
            households[msg.sender].solarMeterID = encryptedSolarMeterID;
        } else{
            households[msg.sender].solarMeterID = "0";
        }

        households[msg.sender].netMeterID = encryptedNetMeterID;
        households[msg.sender].meterOperator = _meterOperator;
        households[msg.sender].Biller = _Biller;
        households[msg.sender].isAllreadyRegistered = true;
    }

    function setMeterOperator(address _meterOperator, string memory encryptedSolarMeterID, string memory encryptedNetMeterID) public{
        require(households[msg.sender].isAllreadyRegistered);
        require(meterOperators[_meterOperator]);
        households[msg.sender].meterOperator = _meterOperator;

        //if household is a Consumer set by convention solarMeterID to "0"
        if (keccak256(abi.encodePacked(encryptedSolarMeterID)) != keccak256(abi.encodePacked(""))) {
            households[msg.sender].solarMeterID = encryptedSolarMeterID;
        } else{
            households[msg.sender].solarMeterID = "0";
        }

        households[msg.sender].netMeterID = encryptedNetMeterID;
    }

    function setBiller(address _Biller, string memory encryptedSolarMeterID, string memory encryptedNetMeterID) public{
        require(households[msg.sender].isAllreadyRegistered);
        require(Billers[_Biller]);
        households[msg.sender].Biller = _Biller;

        //if household is a Consumer set by convention solarMeterID to "0"
        if (keccak256(abi.encodePacked(encryptedSolarMeterID)) != keccak256(abi.encodePacked(""))) {
            households[msg.sender].solarMeterID = encryptedSolarMeterID;
        } else{
            households[msg.sender].solarMeterID = "0";
        }

        households[msg.sender].netMeterID = encryptedNetMeterID;
    }

    function addReader(address reader) public {
        require(households[msg.sender].isAllreadyRegistered);

        households[msg.sender].readers.push(reader);
    }

    //delete algortihm is taken from https://github.com/mitmedialab/medrec/blob/master/SmartContracts/contracts/Agent.sol
    function deleteReader(address reader, string memory encryptedSolarMeterID, string memory encryptedNetMeterID) public {

        bool overwrite = false;
        for(uint index = 0; index < households[msg.sender].readers.length; index++) {
          if(overwrite) {
            households[msg.sender].readers[index - 1] = households[msg.sender].readers[index];
          }
          if(households[msg.sender].readers[index] == reader) {
            overwrite = true;
          }
        }

        delete(households[msg.sender].readers[households[msg.sender].readers.length-1]);
        households[msg.sender].readers.length -= 1;

        //if household is a Consumer set by convention solarMeterID to "0"
        if (keccak256(abi.encodePacked(encryptedSolarMeterID)) != keccak256(abi.encodePacked(""))) {
            households[msg.sender].solarMeterID = encryptedSolarMeterID;
        } else{
            households[msg.sender].solarMeterID = "0";
        }

        households[msg.sender].netMeterID = encryptedNetMeterID;
    }

    function getMeterIDs(address _householdAddress) public hasReadPermission(_householdAddress) view
    returns(string memory _encryptedSolarMeterID, string memory _encryptedNetMeterID){

        return (households[_householdAddress].solarMeterID, households[_householdAddress].netMeterID);
    }

    modifier hasReadPermission(address _householdAddress) {
        bool permissionValid;
        if(msg.sender==_householdAddress) permissionValid = true;
        if(msg.sender==households[_householdAddress].meterOperator) permissionValid = true;
        if(msg.sender==households[_householdAddress].Biller) permissionValid = true;

        for(uint index = 0; index < households[_householdAddress].readers.length; index++) {
          if(msg.sender==households[_householdAddress].readers[index]) {
            permissionValid = true;
            break;
          }
        }

        require(permissionValid);
        _;
    }

    // registration of meter operators and Billers
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //Just basic registration for testing household registration. In a later version the meter operator should be validated
    function registerAsMeterOperator() public{
        require(households[msg.sender].isAllreadyRegistered==false); //address can't be a household
        require(meterOperators[msg.sender]==false);
        meterOperators[msg.sender]=true;
    }

    //Just basic registration for testing household registration. In a later version the biller should be validated
    function registerAsBiller() public{
        require(households[msg.sender].isAllreadyRegistered==false); //address can't be a household
        require(Billers[msg.sender]==false);
        Billers[msg.sender]=true;
    }

    //basic validation for meter operator. The contractOwner can deregister them.
    function deregisterMeterOperator(address _meterOperator) public isOwner(msg.sender){
        meterOperators[_meterOperator]=false;
    }

    //basic validation for meter operator. The biller can deregister them.
    function deregisterBiller(address _Biller) public isOwner(msg.sender){
        Billers[_Biller]=false;
    }

    modifier isOwner(address sender) {
        require(sender==contractOwner);
        _;
    }

    //storage logic
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    struct meterEntry {
        bool isSet;
        int count;
    }

    //bytes32 stands for a measurementKey which has to be computed off chain as keccak256 of householdID, smart (solar or net) meter ID, start time, end time
    mapping (bytes32 => meterEntry) meterEntries;

    //example values for tests:
    //0x0000000000000000000000000000000000000000000000000000000000000001
    //0x0000000000000000000000000000000000000000000000000000000000000002
    function addMeasurement(bytes32 measurementKey, int _count ) public isMeterOperator(msg.sender){
        require(meterEntries[measurementKey].isSet == false);

        meterEntries[measurementKey].count = _count;
        meterEntries[measurementKey].isSet = true;
    }

    modifier isMeterOperator(address _addressOfSender){
        require(meterOperators[_addressOfSender]);
        _;
    }

    //request a blanc measurement
    function getMeasurement(bytes32 measurementKey) public view returns (int){
        require(meterEntries[measurementKey].isSet == true);
        return (meterEntries[measurementKey].count);
    }

    //calculation of stored and not fed in renewable energy
    //_storageAccount is the amount of renewable generation in storgae that may come from earlier calculations
    function getStorageAccount(bytes32 measurementKeySolar_t0, bytes32 measurementKeySolar_tn, bytes32 measurementKeyNet_t0,
    bytes32 measurementKeyNet_tn,int _storageAccount) public view returns (int _storageAccountNew){

        int storageAccount = _storageAccount;

        int solarMeasurement_t0 = meterEntries[measurementKeySolar_t0].count;
        int solarMeasurement_tn = meterEntries[measurementKeySolar_tn].count;
        int energyCreated = solarMeasurement_tn - solarMeasurement_t0;
        storageAccount = storageAccount + energyCreated;
        int feedINMeasurement_t0 = meterEntries[measurementKeyNet_t0].count;
        int feedINMeasurement_tn = meterEntries[measurementKeyNet_tn].count;
        int feedIn = feedINMeasurement_t0 - feedINMeasurement_tn;

        if (feedIn > 0 && storageAccount >0) {
            storageAccount = storageAccount - feedIn;
            if (storageAccount < 0) {
                storageAccount = 0; //energy was fed in that had no renewable origin
            }
        }

        return (storageAccount);
    }

    //when feed in energy this will return a negative value
    function getConsumption(bytes32 measurementKeyNet_t0, bytes32 measurementKeyNet_tn) public view returns(int){
        int feedINMeasurement_t0 = meterEntries[measurementKeyNet_t0].count;
        int feedINMeasurement_tn = meterEntries[measurementKeyNet_tn].count;
        int consumption = feedINMeasurement_tn - feedINMeasurement_t0;
        return consumption;
    }

    function getRenewableProduction(bytes32 measurementKeySolar_t0, bytes32 measurementKeySolar_tn) public view returns (int _amount){
        int solarMeterMeasurement_t0 = meterEntries[measurementKeySolar_t0].count;
        int solarMeterMeasurement_tn = meterEntries[measurementKeySolar_tn].count;
        int production = solarMeterMeasurement_tn - solarMeterMeasurement_t0;
        return production;
    }
}
