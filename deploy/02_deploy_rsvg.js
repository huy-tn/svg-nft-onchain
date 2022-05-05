let { networkConfig, getNetworkIdFromName } = require("../helper-hardhat-config");

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
    const { deploy, get, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();

    let linkTokenAddress;
    let vrfCoordinatorAddress;

    if (chainId == 31337) {
        log("Local network detected! Deploying Mocks...");

        let linkToken = await get("LinkToken");
        let vrfCoordinatorsMock = await get("VRFCoordinatorMock");

        linkTokenAddress = linkToken.address;
        vrfCoordinatorAddress = vrfCoordinatorsMock.address;
    } else {
        linkTokenAddress = networkConfig[chainId]["linkToken"];
        vrfCoordinatorAddress = networkConfig[chainId]["vrfCoordinator"];
    }

    const keyHash = networkConfig[chainId]["keyHash"];
    const fee = networkConfig[chainId]["fee"];

    let args = [vrfCoordinatorAddress, linkTokenAddress, keyHash, fee];

    const RandomSVG = await deploy("RandomSVG", {
        from: deployer,
        args: args,
        log: true,
    });
    log(`Deployed RandomSVG at ${RandomSVG.address}`);
    const networkName = networkConfig[chainId]["name"];
    log(
        `Verify with npx hardhat ${networkName} ${RandomSVG.address} ${args
            .toString()
            .replace(/,/g, " ")}`
    );
    const RandomSVGContract = await ethers.getContractFactory("RandomSVG");
    const accounts = await hre.ethers.getSigners();
    const signer = accounts[0];
    const randomSVG = new ethers.Contract(
        RandomSVG.address,
        RandomSVGContract.interface,
        signer
    );

    // fund with LINK
    let networkId = await getNetworkIdFromName(network.name);
    const fundAmount = networkConfig[networkId]["fundAmount"];
    const linkTokenContract = await ethers.getContractFactory("LinkToken");

    const linkToken = new ethers.Contract(
        linkTokenAddress,
        linkTokenContract.interface,
        signer
    );

    let fund_tx = await linkToken.transfer(RandomSVG.address, fee);
    await fund_tx.wait(1);


    let creation_tx = await randomSVG.create({ gasLimit: 300000 });
    let receipt = await creation_tx.wait(1);
    let tokenId = receipt.events[3].topics[2];
    log(`You've made NFT with id ${tokenId.toString()}`);
    log(`Wait for ChainLink`);

    if (chainId != 31337) {
    } else {
        const VRFCoordinatorMock = await deployments.get("VRFCoordinatorMock");
        vrfCoordinator = await ethers.getContractAt(
            "VRFCoordinatorMock",
            VRFCoordinatorMock.address,
            signer
        );
        let vrf_tx = await vrfCoordinator.callBackWithRandomness(
            receipt.logs[3].topics[1],
            77777,
            randomSVG.address
        );
        await vrf_tx.wait(1);
        log(`Now finish minting process`);
        let finish_tx = await randomSVG.finishMint(tokenId, {
            gasLimit: 2000000,
        });
        await finish_tx.wait(1);
        log(`Your token URI ${await randomSVG.tokenURI(tokenId)}`);
    }
};
module.exports.tags = ["all", "rsvg"];
