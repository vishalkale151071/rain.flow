import { Address, BigInt, dataSource } from "@graphprotocol/graph-ts";
import {
  MetaV1 as MetaV1Event,
  NewClone as NewCloneEvent,
} from "../generated/CloneFactory/CloneFactory";

import { CloneFactory } from "../generated/schema";

import {
  Flow,
  FlowERC20,
  FlowERC721,
  FlowERC1155,
} from "../generated/templates";

export function handleMetaV1(event: MetaV1Event): void {}

export function handleNewClone(event: NewCloneEvent): void {
  let cloneFactory = CloneFactory.load(event.address.toHexString());
  if (cloneFactory == null) {
    cloneFactory = new CloneFactory(event.address.toHexString());
    cloneFactory.childrenCount = BigInt.zero();
    cloneFactory.address = event.address;
    cloneFactory.flowImplementation = Address.zero();
    cloneFactory.flowERC20Implementation = Address.zero();
    cloneFactory.flowERC721Implementation = Address.zero();
    cloneFactory.flowERC1155Implementation = Address.zero();
    cloneFactory.save();
  }
  let context = dataSource.context();
  context.setString("cloneFactory", event.address.toHexString());
  context.setBytes("implementation", event.params.implementation);
  if (event.params.implementation === cloneFactory.flowImplementation) {
    Flow.createWithContext(event.params.clone, context);
  } else if (
    event.params.implementation === cloneFactory.flowERC20Implementation
  ) {
    FlowERC20.createWithContext(event.params.clone, context);
  } else if (
    event.params.implementation === cloneFactory.flowERC721Implementation
  ) {
    FlowERC721.createWithContext(event.params.clone, context);
  } else if (
    event.params.implementation === cloneFactory.flowERC1155Implementation
  ) {
    FlowERC1155.createWithContext(event.params.clone, context);
  }
}
