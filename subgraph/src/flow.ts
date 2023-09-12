import { dataSource } from "@graphprotocol/graph-ts";
import { Initialize } from "../generated/templates/Flow/Flow";
import { Flow } from "../generated/schema";
import { createTransaction } from "./utils/utils";

export function handleInitialize(event: Initialize): void {
  let context = dataSource.context();
  let cloneFactory = context.getString("cloneFactory");
  let flow = new Flow(event.address.toHexString());
  flow.cloneFactory = cloneFactory;
  flow.address = event.address;
  flow.implementation = context.getBytes("implementation");
  flow.deployer = event.params.sender;
  flow.deployTransaction = createTransaction(event.transaction, event.block).id;
  flow.save();
}