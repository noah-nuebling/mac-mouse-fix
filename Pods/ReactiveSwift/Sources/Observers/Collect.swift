extension Operators {
	internal final class Collect<Value, Error: Swift.Error>: Observer<Value, Error> {
		let downstream: Observer<[Value], Error>
		let modify: (_ collected: inout [Value], _ latest: Value) -> [Value]?

		private var values: [Value] = []
		private var hasReceivedValues = false

		convenience init(downstream: Observer<[Value], Error>, shouldEmit: @escaping (_ collected: [Value], _ latest: Value) -> Bool) {
			self.init(downstream: downstream, modify: { collected, latest in
				if shouldEmit(collected, latest) {
					defer { collected = [latest] }
					return collected
				}

				collected.append(latest)
				return nil
			})
		}

		convenience init(downstream: Observer<[Value], Error>, shouldEmit: @escaping (_ collected: [Value]) -> Bool) {
			self.init(downstream: downstream, modify: { collected, latest in
				collected.append(latest)

				if shouldEmit(collected) {
					defer { collected.removeAll(keepingCapacity: true) }
					return collected
				}

				return nil
			})
		}

		private init(downstream: Observer<[Value], Error>, modify: @escaping (_ collected: inout [Value], _ latest: Value) -> [Value]?) {
			self.downstream = downstream
			self.modify = modify
		}

		override func receive(_ value: Value) {
			if let outgoing = modify(&values, value) {
				downstream.receive(outgoing)
			}

			if !hasReceivedValues {
				hasReceivedValues = true
			}
		}

		override func terminate(_ termination: Termination<Error>) {
			if case .completed = termination {
				if !values.isEmpty {
					downstream.receive(values)
					values.removeAll()
				} else if !hasReceivedValues {
					downstream.receive([])
				}
			}

			downstream.terminate(termination)
		}
	}
}
