module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await getChainId();
    log(chainId);

    if (chainId == 31337) {
        log("Local network detected! Deploying Mocks...");

        const linkToken = await deploy("LinkToken", {
            from: deployer,
            log: true,
        });
        const vrfCoordinator = await deploy("VRFCoordinatorMock", {
            from: deployer,
            log: true,
            args: [linkToken.address],
        });

        log("Mocks deployed");
    }
};

module.exports.tags = ["all", "rsvg", "rsvgx"];
