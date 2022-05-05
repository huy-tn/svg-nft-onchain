// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "base64-sol/base64.sol";

contract RandomSVG is ERC721URIStorage, VRFConsumerBase {
    bytes32 public keyHash;
    uint256 public fee;
    uint256 public tokenCounter;

    uint256 public maxNumberOfPaths;
    uint256 public maxNumberOfPathCommands;
    uint256 public size;
    string[] public pathCommands;
    string[] public colors;

    mapping(bytes32 => address) public requestIdToSender;
    mapping(bytes32 => uint256) public requestIdToTokenId;
    mapping(uint256 => uint256) public tokenIdToRandomNumber;

    event requestedRandomSVG(
        bytes32 indexed requestId,
        uint256 indexed tokenId
    );
    event createdUnfinishedRandomSVG(
        uint256 indexed tokenId,
        uint256 randomNumber
    );
    event createdRandomSVG(uint256 indexed tokenId, string tokenURI);

    constructor(
        address _VRFCoordinator,
        address _LinkToken,
        bytes32 _keyHash,
        uint256 _fee
    )
        VRFConsumerBase(_VRFCoordinator, _LinkToken)
        ERC721("RandomSVG", "rsNFT")
    {
        fee = _fee;
        keyHash = _keyHash;
        tokenCounter = 0;
        maxNumberOfPaths = 10;
        maxNumberOfPathCommands = 5;
        size = 50;
        pathCommands = ["M", "L"];
        colors = ["red", "blue", "green", "yellow", "black"];
    }

    function create() public returns (bytes32 requestId) {
        requestId = requestRandomness(keyHash, fee);
        requestIdToSender[requestId] = msg.sender;
        uint256 tokenId = tokenCounter;
        requestIdToTokenId[requestId] = tokenId;
        tokenCounter += 1;

        emit requestedRandomSVG(requestId, tokenId);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomNumber)
        internal
        override
    {
        address nftOwner = requestIdToSender[_requestId];
        uint256 tokenId = requestIdToTokenId[_requestId];

        _safeMint(nftOwner, tokenId);
        tokenIdToRandomNumber[tokenId] = _randomNumber;
        emit createdUnfinishedRandomSVG(tokenId, _randomNumber);
    }

    function finishMint(uint256 _tokenId) public {
        require(
            bytes(tokenURI(_tokenId)).length <= 0,
            "tokenURI is already set"
        );
        require(tokenCounter > _tokenId, "tokenId has not been minted");
        require(
            tokenIdToRandomNumber[_tokenId] > 0,
            "need to wait for ChainLink to fulfill"
        );

        uint256 randomNumber = tokenIdToRandomNumber[_tokenId];
        string memory svg = generateSVG(randomNumber);
        string memory imageURI = svgToImageURI(svg);
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(_tokenId, tokenURI);
        emit createdRandomSVG(_tokenId, tokenURI);
    }

    function generateSVG(uint256 _randomNumber)
        public
        view
        returns (string memory finalSvg)
    {
        uint256 numberOfPaths = (_randomNumber % maxNumberOfPaths) + 1;
        // finalSvg = string(
        //     abi.encodePacked(
        //         '<svg xmlns="http://www.w3.org/2000/svg" height=',
        //         Strings.toString(size),
        //         ' "width =',
        //         Strings.toString(size),
        //         '"/>'
        //     )
        // );
        finalSvg = string(
            abi.encodePacked(
                "<svg xmlns='http://www.w3.org/2000/svg' height='",
                Strings.toString(size),
                "' width='",
                Strings.toString(size),
                "'>"
            )
        );

        for (uint256 i = 0; i < numberOfPaths; i++) {
            uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, i)));
            string memory pathSvg = generatePath(newRNG);
            finalSvg = string(abi.encodePacked(finalSvg, pathSvg));
        }

        finalSvg = string(abi.encodePacked(finalSvg, "</svg>"));
    }

    function generatePath(uint256 _randomNumber)
        public
        view
        returns (string memory pathSvg)
    {
        uint256 numberOfPathCommands = (_randomNumber %
            maxNumberOfPathCommands) + 1;
        pathSvg = '<path d="';
        for (uint256 i = 0; i < numberOfPathCommands; i++) {
            uint256 newRNG = uint256(keccak256(abi.encode(_randomNumber, i)));
            string memory pathCommandSvg = generatePathCommand(newRNG);
            pathSvg = string(abi.encodePacked(pathSvg, pathCommandSvg));
        }
        string memory color = colors[_randomNumber % colors.length];
        pathSvg = string(
            abi.encodePacked(
                pathSvg,
                '" fill="transparent" stroke="',
                color,
                '"/>'
            )
        );
    }

    function generatePathCommand(uint256 _randomness)
        public
        view
        returns (string memory pathCommand)
    {
        pathCommand = pathCommands[_randomness % pathCommands.length];
        uint256 parameterOne = uint256(
            keccak256(abi.encode(_randomness, size * 2))
        ) % size;
        uint256 parameterTwo = uint256(
            keccak256(abi.encode(_randomness, size * 2 + 1))
        ) % size;
        pathCommand = string(
            abi.encodePacked(
                pathCommand,
                " ",
                Strings.toString(parameterOne),
                " ",
                Strings.toString(parameterTwo)
            )
        );
    }

    function svgToImageURI(string memory svg)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(svg)))
        );
        string memory imageURI = string(
            abi.encodePacked(baseURL, svgBase64Encoded)
        );
        return imageURI;
    }

    function formatTokenURI(string memory imageURI)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:application/json;base64,";
        return
            string(
                abi.encodePacked(
                    baseURL,
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"SVGNFT", "description":"An NFT based on SVG!", "attributes":"","image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
