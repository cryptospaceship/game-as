pragma solidity 0.4.24;

import "./Mortal.sol";
import "./AddressUtils.sol";
import "./SpaceShipInterface.sol";
import "./GameSpacialPort.sol";

contract GameFactory is Mortal, GameSpacialPort {

    bytes32 version;
    address spaceShipContract;
    address candidate;
    address winner;
    address admin;
    SpaceShipInterface spaceShipInterface;
    bool gameReady;
    uint gameLaunch;
    uint gamePlayValue;
    uint endBlock;


    using AddressUtils for address;

    modifier onlyOwnerOrAdmin() {
        require(msg.sender == owner || msg.sender == admin);
        _;
    }

    function setAdmin(address _admin)
        external
        onlyOwner
    {
        admin = _admin;
    }

    function delAdmin()
        external
        onlyOwner
    {
        admin = address(0);
    }


    function getGame()
        external
        view
        returns(string name, uint launch, uint reward, uint playvalue)
    {
        name = "Juego";
        launch = gameLaunch;
        reward = address(this).balance;
        playvalue = gamePlayValue;
    }

    function getGame2() 
        external
        view
        returns(
            bytes32 _version, 
            bool _gameReady, 
            uint _gameLaunch,
            uint _gamePlayValue,
            uint _endBlock,
            uint _reward,
            address _candidate,
            address _winner
        )
    {
        _version = version;
        _gameReady = gameReady;
        _candidate = candidate;
        _winner = winner;
        _gameLaunch = gameLaunch;
        _gamePlayValue = gamePlayValue;
        _endBlock = endBlock;
        _reward = address(this).balance;
    }

    modifier isGameReady() {
        require(gameReady);
        _;
    }

    modifier isGameStart() {
        require(isGameStarted());
        _;
    }

    modifier onlySpaceShipContract() {
        require(msg.sender == spaceShipContract);
        _;
    }

    constructor() public {
        spaceShipContract = address(0);
        version = "1.3.2-AS";
        candidate = address(0);
        endBlock = 0;
        gameReady = false;
        gameLaunch = 0;
        gamePlayValue = 0.1 ether;
    }

    event WinnerEvent(
        address winner,
        uint reward
    );

    function claimVictory()
        external
        isGameReady

    {
        require(candidate != address(0) && endBlock <= block.number && endBlock != 0);
        winner = candidate;
        endBlock = 0;
        gameReady = false;

        emit WinnerEvent(
            winner,
            address(this).balance
        );
        candidate.transfer(address(this).balance);
    }


    function setGameAttributes(address _shipContract, uint _startAt)
        external
        onlyOwnerOrAdmin
    {
        setSpaceShipContract(_shipContract);
        if (_startAt == 0)
            gameLaunch = block.number;
        else
            gameLaunch = _startAt;
        gameReady = true;
    }

    function setGameAttributes(address _shipContract, uint _startAt, uint mapSideSize)
        external
        onlyOwnerOrAdmin
    {
        setSpaceShipContract(_shipContract);
        if (_startAt == 0)
            gameLaunch = block.number;
        else
            gameLaunch = _startAt;

        /*
         * Se le cambia el tamaño al mapa
         */
        changeMapSize(mapSideSize);
        
        gameReady = true;
    }

    function setSpaceShipContract(address _address)
        internal
    {
        require(_address.isContract());
        /**
         TODO: Check if a valid contract, maybe using ERC165
         */
        spaceShipContract = _address; 
        spaceShipInterface = SpaceShipInterface(_address);
    }

    function isGameStarted() 
        internal
        view
        returns(bool)
    {
        return (gameReady && block.number >= gameLaunch);
    }
}

