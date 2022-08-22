import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;

    const { deployer } = await getNamedAccounts();

    const conditionalTokens = await deployments.deploy("ConditionalTokens",{from: deployer, args: []});

    const t = await deployments.deploy("Treasury", {
        from: deployer,
        args: [conditionalTokens.address, '0xfe4F5145f6e09952a5ba9e956ED0C25e3Fa4c7F1'],
    });
};

export default func;
