//
//  MainScreen.swift
//  TodoAppSwiftUI3
//
//  Created by Roman Luzgin on 22.06.21.
//

import SwiftUI
import CoreData
import RiveRuntime

let buttonWidth: CGFloat = 60

enum CellButtons: Identifiable {
    case edit
    case delete
    case save
    case info
    
    var id: String {
        return "\(self)"
    }
}

struct CellButtonView: View {
    let data: CellButtons
    let cellHeight: CGFloat
    
    func getView(for image: String, title: String) -> some View {
        VStack {
            Image(systemName: image)
            Text(title)
        }
        .foregroundColor(.primary)
        .font(.subheadline)
        .frame(width: buttonWidth, height: cellHeight)
    }
    
    var body: some View {
        switch data {
        case .edit:
            getView(for: "pencil.circle", title: "Edit")
            .background(Color.pink)
        case .delete:
            getView(for: "delete.right", title: "Delete")
            .background(Color.red)
        case .save:
            getView(for: "square.and.arrow.down", title: "Save")
            .background(Color.blue)
        case .info:
            getView(for: "info.circle", title: "Info")
            .background(Color.green)
        }
    }
}

struct ContentCell: View {
    let data: String
    var body: some View {
        VStack {
            HStack {
                Text(data)
                Spacer()
            }.padding()
            Divider()
                .padding(.leading)
        }
    }
}


extension View {
    func addButtonActions(rowSize: CGFloat, leadingButtons: [CellButtons], trailingButton: [CellButtons], onClick: @escaping (CellButtons) -> Void) -> some View {
        self.modifier(SwipeContainerCell(rowSize: rowSize, leadingButtons: leadingButtons, trailingButton: trailingButton, onClick: onClick))
    }
}

struct SwipeContainerCell: ViewModifier  {
    enum VisibleButton {
        case none
        case left
        case right
    }
    @State private var offset: CGFloat = 0
    @State private var oldOffset: CGFloat = 0
    @State private var visibleButton: VisibleButton = .none
//    let leadingButtons: [AnyView]
//    let trailingButton: [AnyView]
    let leadingButtons: [CellButtons]
    let trailingButton: [CellButtons]
    let leftRiveVm: RiveViewModel
    let rightRiveVm: RiveViewModel
    
    let rowSize: CGFloat

    let maxLeadingOffset: CGFloat
    let minTrailingOffset: CGFloat
    let onClick: (CellButtons) -> Void
    
    init(rowSize: CGFloat, leadingButtons: [CellButtons], trailingButton: [CellButtons], onClick: @escaping (CellButtons) -> Void) {
        self.rowSize = rowSize
        self.leftRiveVm = RiveViewModel(fileName: "swipe", stateMachineName: "State Machine 1", fit: .cover, alignment: .centerLeft)
        self.rightRiveVm = RiveViewModel(fileName: "swipe", stateMachineName: "State Machine 1", fit: .cover, alignment: .centerRight)
        self.leadingButtons = leadingButtons
        self.trailingButton = trailingButton
        // TODO: These are arbitrary values, ideally its the width of the todo item row
        maxLeadingOffset = (rowSize - 60)
        debugPrint("MAX SIZE \(rowSize)")
        minTrailingOffset = (rowSize - 60) * -1
        self.onClick = onClick
    }
    
    func reset() {
        visibleButton = .none
        offset = 0
        oldOffset = 0
    }
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .contentShape(Rectangle()) ///otherwise swipe won't work in vacant area
        .offset(x: offset)
        .gesture(DragGesture(minimumDistance: 15, coordinateSpace: .local)
        .onChanged({ (value) in
            let totalSlide = value.translation.width + oldOffset
            // TODO: Need to find the max slide to get a percentage
            if totalSlide >= 0 {
                debugPrint("HIT \((totalSlide / maxLeadingOffset) * 100)")
                leftRiveVm.setInput("Swipe Direction", value: (totalSlide / maxLeadingOffset) * 100)
            } else {
                rightRiveVm.setInput("Swipe Direction", value: (totalSlide / maxLeadingOffset) * 100)
            }
            if  (0...Int(maxLeadingOffset) ~= Int(totalSlide)) || (Int(minTrailingOffset)...0 ~= Int(totalSlide)) { //left to right slide
                withAnimation{
                    offset = totalSlide
                }
            }
            ///can update this logic to set single button action with filled single button background if scrolled more then buttons width
        })
        .onEnded({ value in
            withAnimation {
              if visibleButton == .left && value.translation.width < -20 { ///user dismisses left buttons
                reset()
             } else if  visibleButton == .right && value.translation.width > 20 { ///user dismisses right buttons
                reset()
             } else if offset > (rowSize / 2) || offset < ((rowSize / 2) * -1) { ///scroller more then 50% show button
                if offset > 0 {
                    visibleButton = .left
                    offset = maxLeadingOffset
                    leftRiveVm.setInput("Swipe Direction", value: 100.0)
                } else {
                    visibleButton = .right
                    offset = minTrailingOffset
                    leftRiveVm.setInput("Swipe Direction", value: -100.0)
                }
                oldOffset = offset
                ///Bonus Handling -> set action if user swipe more then x px
            } else {
                reset()
            }
         }
        }))
            GeometryReader { proxy in
                HStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack {
                        leftRiveVm.view()
                    }
                }.offset(x: (-1 * maxLeadingOffset) + offset)
                Spacer()
                HStack(spacing: 0) {
                    rightRiveVm.view()
                }.offset(x: (-1 * minTrailingOffset) + offset)
            }
        }
        }
    }
}

struct MainScreen: View {
    @Environment(\.managedObjectContext) var viewContext
    
    @Namespace private var namespace
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    private var todaysItems: [Item] {
        items.filter {
            Calendar.current.isDate($0.dueDate ?? Date(), equalTo: Date(), toGranularity: .day)
        }
    }
    
    @State var newItemOpen = false
    @State var settingsOpen = false
    
    @Binding var menuOpen: Bool
    
    
    @AppStorage("userName") var userName = ""
    
    var body: some View {
        ScrollView {
            LazyVStack.init(spacing: 0, pinnedViews: [.sectionHeaders], content: {
                Section.init(header: HStack {
                    Text("Section 1")
                    Spacer()
                })
                {
                    ForEach(1...10, id: \.self) { count in
                            ContentCell(data: "cell \(count)")
                            .addButtonActions(rowSize: UIScreen.main.bounds.size.width, leadingButtons: [.save],
                                                  trailingButton:  [.delete], onClick: { button in
                                                    print("clicked: \(button)")
                                                  })
                    }
                }
            })
        }
//        ZStack {
//            if !newItemOpen {
//                NavigationView {
//                    ZStack {
//                        ScrollView {
//                            VStack {
//                                HStack {
//                                    Text("Categories")
//                                        .font(.body.smallCaps())
//                                        .foregroundColor(.secondary)
//                                    Spacer()
//                                }
//                                .padding(.horizontal)
//
//
//                                ScrollView(.horizontal, showsIndicators: false) {
//                                    LazyHStack(spacing: 20) {
//                                        ForEach(categories) {category in
//                                            CategoryCards(category: category.category,
//                                                          color: category.color,
//                                                          numberOfTasks: getTotalTasksNumber(category: category),
//                                                          tasksDone: getDoneTasksNumber(category: category))
//                                        }
//                                        .padding(.bottom, 30)
//
//                                    }
//                                    .padding(.leading, 20)
//                                    .padding(.trailing, 30)
//                                }
//                                .frame(height: 190)
//
//                            }
//                            .padding(.top, 30)
//
//                            // MARK: Actual list of todo items
//                            VStack {
//                                HStack {
//                                    Text("Today's tasks")
//                                        .font(.body.smallCaps())
//                                        .foregroundColor(.secondary)
//                                    Spacer()
//                                }
//                                .padding(.horizontal)
//
//                                if todaysItems.count > 0 {
//                                    List {
//                                        Text("TAYLOR SWIFT")
//                                            .swipeActions {
//                                                Button {
//                                                    print("Hi")
//                                                } label: {
//                                                    Label("Send message", systemImage: "message")
//                                                }
//                                            }
//                                    }
////                                    List {
////                                        LazyVStack(spacing: 10) {
////                                            ForEach(todaysItems) { toDoItem in
////
////                                                // MARK: Today's tasks list view
////                                                VStack {
////                                                    HStack {
////                                                        Image(systemName: toDoItem.isDone ? "circle.fill" : "circle")
////                                                            .resizable()
////                                                            .foregroundColor(getCategoryColor(toDoItem: toDoItem))
////                                                            .frame(width: 30, height: 30)
////                                                            .onTapGesture {
////                                                                withAnimation {
////                                                                    ViewContextMethods.isDone(item: toDoItem, context: viewContext)
////                                                                }
////                                                            }
////                                                            .padding(.leading, 20)
////                                                            .padding(.trailing, 10)
////
////                                                        Text("\(toDoItem.toDoText ?? "")")
////                                                            .swipeActions {
////                                                                riveVm.view()
////                                                            }
////                                                        Spacer()
////                                                    }
////                                                    .swipeActions {
////                                                        riveVm.view()
////                                                    }
////                                                }
////                                                .frame(maxWidth: .infinity)
////                                                .frame(height: 100)
////                                                .swipeActions {
////                                                    riveVm.view()
////                                                }
////                                                .background(
////                                                    ZStack {
////                                                    getCategoryColor(toDoItem: toDoItem).opacity(0.7)
////                                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
////                                                        .padding(.horizontal, 30)
////                                                        .padding(.vertical, 20)
////                                                    VStack {
////                                                        // empty VStack for the blur
////                                                    }
////                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
////                                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
////                                                },
////                                                    alignment: .leading
////                                                )
////                                                .shadow(color: .black.opacity(0.1), radius: 20, x: 5, y: 10)
////                                                .shadow(color: .black.opacity(0.1), radius: 1, x: 1, y: 1)
////                                                .shadow(color: .white.opacity(1), radius: 5, x: -1, y: -1)
////                                                .padding(.horizontal)
////                                            }
////                                        }
////                                    }
////                                    .padding(.bottom, 60)
//                                } else {
//                                    VStack{
//                                        Text("No tasks for today")
//                                            .foregroundColor(.secondary)
//                                    }
//                                    .frame(height: 200)
//                                }
//                            }
//                        }
//
//                        // MARK: Bottom button to add new item
//                        VStack{
//                            Spacer()
//                            HStack{
//                                Spacer()
//                                Button(action: {
//                                    withAnimation {
//                                        newItemOpen.toggle()
//                                    }
//                                }) {
//                                    Image(systemName: "plus.circle.fill")
//                                        .resizable()
//                                        .frame(width: 70, height: 70)
//                                        .foregroundColor(.indigo)
//                                        .shadow(color: .indigo.opacity(0.3), radius: 10, x: 0, y: 10)
//                                        .padding()
//                                }
//                            }
//                            .matchedGeometryEffect(id: "button", in: namespace)
//                        }
//                    }
//                    .navigationTitle(userName.isEmpty ? "Hi there!" : "What's up, \(userName)!")
//
//                    // MARK: Navigation bar buttons to open different menus
//                    .navigationBarItems(
//
//
//                        leading: Button(action: {
//                        withAnimation {
//                            menuOpen.toggle()
//                        }
//                        Haptics.giveSmallHaptic()
//                    })
//                        {
//                        Image(systemName: "rectangle.portrait.leftthird.inset.filled")
//                            .foregroundColor(Color.indigo)
//                    }
//                            .buttonStyle(PlainButtonStyle()),
//                        trailing: Button(action: {
//                        withAnimation {
//                            settingsOpen.toggle()
//                        }
//                        Haptics.giveSmallHaptic()
//                    }) {
//                        Image(systemName: "gear.circle.fill")
//                            .resizable()
//                            .frame(width: 40, height: 40)
//                            .foregroundColor(Color.indigo)
//
//                    }
//                            .buttonStyle(PlainButtonStyle())
//                            .sheet(isPresented: $settingsOpen, onDismiss: {settingsOpen = false}) {Settings()}
//                    )
//                }
//
//                // MARK: New item view
//            } else {
//                NewItem(namespace: namespace, newItemOpen: $newItemOpen)
//            }
//        }
    }
    
    // MARK: functions
    func getCategoryColor(toDoItem: Item) -> Color {
        var category: [ItemCategory] {
            categories.filter {
                $0.category == toDoItem.category
            }
        }
        
        return category[0].color
    }
    
    func getTotalTasksNumber(category: ItemCategory) -> Int {
        var categoryTasks: [Item] {
            items.filter {
                $0.category == category.category
            }
        }
        
        return categoryTasks.count
    }
    
    func getDoneTasksNumber(category: ItemCategory) -> Int {
        var categoryTasksDone: [Item] {
            items.filter {
                $0.category == category.category && $0.isDone == true
            }
        }
        
        return categoryTasksDone.count
    }
    
}

struct MainScreen_Previews: PreviewProvider {
    static var previews: some View {
        MainScreen(menuOpen: .constant(false))
    }
}

