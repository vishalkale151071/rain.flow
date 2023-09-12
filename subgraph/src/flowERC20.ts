import { dataSource } from "@graphprotocol/graph-ts";
import { Initialize } from "../generated/templates/FlowERC20/FlowERC20";
import { FlowERC20 } from "../generated/schema";
import { createTransaction } from "./utils/utils";

export function handleInitialize(event: Initialize): void {
  let context = dataSource.context();
  let cloneFactory = context.getString("cloneFactory");
  let flowERC20 = new FlowERC20(event.address.toHexString());
  flowERC20.cloneFactory = cloneFactory;
  flowERC20.address = event.address;
  flowERC20.implementation = context.getBytes("implementation");
  flowERC20.deployer = event.params.sender;
  flowERC20.deployTransaction = createTransaction(event.transaction, event.block).id;
  flowERC20.save();
}
