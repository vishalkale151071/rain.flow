import { dataSource } from "@graphprotocol/graph-ts";
import { Initialize } from "../generated/templates/FlowERC1155/FlowERC1155";
import { FlowERC1155 } from "../generated/schema";
import { createTransaction } from "./utils/utils";

export function handleInitialize(event: Initialize): void {
  let context = dataSource.context();
  let flowERC1155 = new FlowERC1155(event.address.toHexString());
  flowERC1155.cloneFactory = context.getString("cloneFactory");
  flowERC1155.address = event.address;
  flowERC1155.implementation = context.getBytes("implementation");
  flowERC1155.deployer = event.params.sender;
  flowERC1155.deployTransaction = createTransaction(event.transaction, event.block).id;
  flowERC1155.save();
}
