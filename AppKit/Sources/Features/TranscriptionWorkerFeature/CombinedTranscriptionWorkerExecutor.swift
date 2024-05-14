//   init() {}

//   func process(task: TranscriptionTaskEnvelope) async {
//     if task.isRemote {
//       await remoteWorkExecutor.process(task: task)
//     } else {
//       await localWorkExecutor.process(task: task)
//     }
//   }

//   func cancel(task: TranscriptionTaskEnvelope) {
//     if task.isRemote {
//       remoteWorkExecutor.cancel(task: task)
//     } else {
//       localWorkExecutor.cancel(task: task)
//     }
//   }
// }
