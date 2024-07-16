module QuestModule
  Chapter1 = {
    :ID => "0",
    :Name => "Chapter 1",
    :QuestGiver => "nil",
    :Stage1 => "Meet Arthur at the Lab.",
    :Stage2 => "Obtain your starter Pokémon.",
    :Stage3 => "Battle Meryl.",
    :Stage4 => "Investigate Feldspar Cave.",
    :Stage5 => "Report to Orion.",
    :Stage6 => "Visit the School.",
    :Stage7 => "Defend the Lab.",
    :Location1 => "Stuot Lab",
    :Location2 => "Stuot Lab",
    :Location3 => "Stuot Lab",
    :Location4 => "Feldspar Cave",
    :Location5 => "Stuot Lab",
    :Location6 => "Stuot School",
    :Location7 => "Stuot Lab",
    :QuestDescription => "Chapter 1 story",
  }
  
  Quest1 = {
    :ID => "1",
    :Name => "Help me find my Lillipup!",
    :QuestGiver => "Lass Selena",
    :Stage1 => "Look for Lillipup",
    :Location1 => "Stuot City",
    :Stage2 => "Look for Lillipup again",
    :Location2 => "Stuot City",
    :Stage3 => "Save Lillipup",
    :Location3 => "Stuot City",
    :QuestDescription => "I lost my Lillipup while taking him for a walk after a Mightyena frightened him! I have been looking around the city but I just can't find him. Can someone help me find him please? I miss him so much. My father's Stoutland gave us another egg so you can take it as a reward if you want.",
    :RewardString => "Pokémon Egg."
  }
  
  Quest2 = {
    :ID => "2",
    :Name => "I need a combee!",
    :QuestGiver => "Youngster Larry",
    :Stage1 => "Catch a combee",
    :Location1 => "Route 1",
    :QuestDescription => "I went to Route 1 to look for a dex entry of combee but I just couldn't find one. It was supposed to be easy, they say it appears 95% of the time but I kept getting other Pokémon on the grass. Am I doing something wrong? If anyone could just catch it would be great. I could then copy the information for my Dex.",
    :RewardString => "1500$ + 5 Great Balls"
  }
  
  # Here's an example of a quest with lots of stages that also doesn't have a stage location defined for every stage
  Quest3 = {
    :ID => "3",
    :Name => "Precious item lost!",
    :QuestGiver => "Beauty Trish",
    :Stage1 => "Look for the Big Pearl",
    :Location1 => "Stuot City",
    :QuestDescription => "I lost my Big Pearl somewhere in the City but I can't find it. It was a gift from my boyfriend and it's worth a lot of money. I'm afraid if someone finds it he will try to sell it. Please help me!",
    :RewardString => "3 Super Potion, 2500$ and a Lum Berry"
  }
  
  # Here's an example of not defining the quest giver and reward text
  Quest4 = {
    :ID => "4",
    :Name => "A new beginning",
    :QuestGiver => "nil",
    :Stage1 => "Turning over a new leaf... literally!",
    :Stage2 => "Help your neighbours.",
    :Location1 => "Milky Way",
    :Location2 => "nil",
    :QuestDescription => "You crash landed on an alien planet. There are other humans here and they look hungry...",
    :RewardString => "nil"
  }
  
  # Other random examples you can look at if you want to fill out the UI and check out the page scrolling
  Quest5 = {
    :ID => "5",
    :Name => "All of my friends",
    :QuestGiver => "Barry",
    :Stage1 => "Meet your friends near Acuity Lake.",
    :QuestDescription => "Barry told me that he saw something cool at Acuity Lake and that I should go see. I hope it's not another trick.",
    :RewardString => "You win nothing for giving in to peer pressure."
  }
  
  Quest6 = {
    :ID => "6",
    :Name => "The journey begins",
    :QuestGiver => "Professor Oak",
    :Stage1 => "Deliver the parcel to the Pokémon Mart in Viridian City.",
    :Stage2 => "Return to the Professor.",
    :Location1 => "Viridian City",
    :Location2 => "nil",
    :QuestDescription => "The Professor has entrusted me with an important delivery for the Viridian City Pokémon Mart. This is my first task, best not mess it up!",
    :RewardString => "nil"
  }
  
  Quest7 = {
    :ID => "7",
    :Name => "Close encounters of the... first kind?",
    :QuestGiver => "nil",
    :Stage1 => "Make contact with the strange creatures.",
    :Location1 => "Rock Tunnel",
    :QuestDescription => "A sudden burst of light, and then...! What are you?",
    :RewardString => "A possible probing."
  }
  
  Quest8 = {
    :ID => "8",
    :Name => "These boots were made for walking",
    :QuestGiver => "Musician #1",
    :Stage1 => "Listen to the musician's, uhh, music.",
    :Stage2 => "Find the source of the power outage.",
    :Location1 => "nil",
    :Location2 => "Celadon City Sewers",
    :QuestDescription => "A musician was feeling down because he thinks no one likes his music. I should help him drum up some business."
  }
  
  Quest9 = {
    :ID => "9",
    :Name => "Got any grapes?",
    :QuestGiver => "Duck",
    :Stage1 => "Listen to The Duck Song.",
    :Stage2 => "Try not to sing it all day.",
    :Location1 => "YouTube",
    :QuestDescription => "Let's try to revive old memes by listening to this funny song about a duck wanting grapes.",
    :RewardString => "A loss of braincells. Hurray!"
  }
  
  Quest10 = {
    :ID => "10",
    :Name => "Singing in the rain",
    :QuestGiver => "Some old dude",
    :Stage1 => "I've run out of things to write.",
    :Stage2 => "If you're reading this, I hope you have a great day!",
    :Location1 => "Somewhere prone to rain?",
    :QuestDescription => "Whatever you want it to be.",
    :RewardString => "Wet clothes."
  }
  
  Quest11 = {
    :ID => "11",
    :Name => "When is this list going to end?",
    :QuestGiver => "Me",
    :Stage1 => "When IS this list going to end?",
    :Stage2 => "123",
    :Stage3 => "456",
    :Stage4 => "789",
    :QuestDescription => "I'm losing my sanity.",
    :RewardString => "nil"
  }
  
  Quest12 = {
    :ID => "12",
    :Name => "The laaast melon",
    :QuestGiver => "Some stupid dodo",
    :Stage1 => "Fight for the last of the food.",
    :Stage2 => "Don't die.",
    :Location1 => "A volcano/cliff thing?",
    :Location2 => "Good advice for life.",
    :QuestDescription => "Tea and biscuits, anyone?",
    :RewardString => "Food, glorious food!"
  }

end
