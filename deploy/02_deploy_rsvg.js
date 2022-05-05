let { networkConfig } = require("../helper-hardhat-config");

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
        log: true,
        args: args,
    });
    log("Deployed RandomSVG");
    networkName = networkConfig[chainId]["name"];
    log(
        `Verify with npx hardhat ${networkName} ${RandomSVG.address} ${args
            .toString()
            .replace(/,/g, " ")}`
    );

    // fund with LINK
    const linkTokenContract = await ethers.getContractFactory("LinkToken");
    const accounts = hre.ethers.getSigners();
    const signer = accounts[0];
    const linkToken = new ethers.Contract(
        linkTokenAddress,
        linkTokenContract.interface,
        signer
    );

    let fund_tx = await linkToken.transfer(RandomSVG.address, fee);
    await fund_tx.wait(1);

    const RandomSVGContract = await ethers.getContractFactory("RandomSVG");
    const RandomSVG = new ethers.Contract();
};
module.exports.tags = ["all", "rsvg"];
