import { dataSource } from "@graphprotocol/graph-ts";
import { Initialize } from "../generated/templates/FlowERC721/FlowERC721";
import { FlowERC721 } from "../generated/schema";
import { createTransaction } from "./utils/utils";

export function handleInitialize(event: Initialize): void {
  let context = dataSource.context();
  let cloneFactory = context.getString("cloneFactory");
  let flowERC721 = new FlowERC721(event.address.toHexString());
  flowERC721.cloneFactory = cloneFactory;
  flowERC721.address = event.address;
  flowERC721.implementation = context.getBytes("implementation");
  flowERC721.deployer = event.params.sender;
  flowERC721.deployTransaction = createTransaction(event.transaction, event.block).id;
  flowERC721.save();
}
