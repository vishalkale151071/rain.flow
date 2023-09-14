import { dataSource } from "@graphprotocol/graph-ts";
import { Initialize, Context, FlowInitialized } from "../generated/templates/Flow/Flow";
import { Evaluable, Flow } from "../generated/schema";
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

export function handleContext(event: Context): void {
  let flow = Flow.load(event.address.toHexString());
}

export function handleFlowInitialized(event: FlowInitialized): void {
  let evaluable = new Evaluable(event.address.toHexString());
  evaluable.interpreter = event.params.evaluable.interpreter;
  evaluable.expression = event.params.evaluable.expression;
  evaluable.store = event.params.evaluable.store;
  evaluable.contract = event.address.toHexString();
  evaluable.save();
}