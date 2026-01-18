const { Client, GatewayIntentBits, SlashCommandBuilder, EmbedBuilder, REST, Routes } = require('discord.js');

const client = new Client({
    intents: [
        GatewayIntentBits.Guilds,
        GatewayIntentBits.GuildMessages,
        GatewayIntentBits.MessageContent,
        GatewayIntentBits.GuildMessageReactions,
    ],
});

const config = exports["fd-clockin"].getConfig();

const token = config.discordToken;
const guildId = config.guildId;

client.once('ready', async () => {
    console.log(`[Discord] Bot logged in as ${client.user.tag}`);

    const { SlashCommandBuilder } = require('discord.js');

    const commands = [
        new SlashCommandBuilder()
            .setName('viewhours')
            .setDescription('View hours of a specific player with various filters')
            .addUserOption(option =>
                option
                    .setName('user')
                    .setDescription('The user whose hours you want to view')
                    .setRequired(true)
            )
            .addStringOption(option =>
                option
                    .setName('filter')
                    .setDescription('The filter for the hours (daily, weekly, monthly, lifetime, specific)')
                    .setRequired(true)
                    .addChoices(
                        { name: 'Daily', value: 'daily' },
                        { name: 'Weekly', value: 'weekly' },
                        { name: 'Monthly', value: 'monthly' },
                        { name: 'Lifetime', value: 'lifetime' },
                        { name: 'Specific Date', value: 'specific' }
                    )
            )
            .addStringOption(option =>
                option
                    .setName('date')
                    .setDescription('Enter a specific date (YYYY-MM-DD) for the "specific" filter')
                    .setRequired(false)
            )
            .setDefaultMemberPermissions(0)
            .setDMPermission(false),

        new SlashCommandBuilder()
            .setName('leaderboard')
            .setDescription('View a leaderboard of top 10')
            .addStringOption(option =>
                option
                    .setName('filter')
                    .setDescription('The filter for the hours (daily, weekly, monthly, lifetime, specific)')
                    .setRequired(true)
                    .addChoices(
                        { name: 'Daily', value: 'daily' },
                        { name: 'Weekly', value: 'weekly' },
                        { name: 'Monthly', value: 'monthly' },
                        { name: 'Lifetime', value: 'lifetime' }
                    )
            )
            .setDefaultMemberPermissions(0)
            .setDMPermission(false),
    ];
    
    module.exports = { commands };
    
    const rest = new REST({ version: '10' }).setToken(token);

    try {
        console.log('Registering commands...');
        await rest.put(
            Routes.applicationGuildCommands(client.user.id, guildId),
            { body: commands }
        );
        console.log('Commands registered successfully!');
    } catch (error) {
        console.error('Error registering commands:', error);
    }
});

client.on('interactionCreate', async interaction => {
    if (interaction.isCommand() && interaction.commandName === 'viewhours') {
        const targetUser = interaction.options.getUser('user');
        const targetMember = await interaction.guild.members.fetch(targetUser.id);

        const filter = interaction.options.getString('filter');
        const specificDate = interaction.options.getString('date');

        if (!targetUser) {
            return interaction.reply({
                content: 'Could not find the user. Please try again.',
                ephemeral: true,
            });
        }

        const formattedDate = specificDate ? specificDate : null;

        try {
            const loadingMessage = await interaction.reply({
                content: 'Loading... Please wait a moment.',
                ephemeral: true,
            });

            const response = await exports["fd-clockin"].getHours(targetUser.id, filter, formattedDate);

            const embed = new EmbedBuilder()
                .setColor(0x00FF00)
                .setTitle(`${targetMember.displayName}'s Hours Report`)
                .setDescription(`Here are the hours for ${targetMember.displayName} based on the filter: **${filter}**\n\n${response}`)
                .setFooter({ text: 'Requested by ' + interaction.member.displayName, iconURL: interaction.user.avatarURL() })
                .setTimestamp();

            await loadingMessage.edit({
                content: null,
                embeds: [embed],
            });

        } catch (error) {
            console.error('Error fetching hours:', error);
            await interaction.reply({
                content: 'An error occurred while fetching the hours. Please try again later.',
                ephemeral: true,
            });
        }
    } else if (interaction.isCommand() && interaction.commandName === 'leaderboard') {
        const filter = interaction.options.getString('filter');
        const specificDate = interaction.options.getString('date');

        const formattedDate = specificDate ? specificDate : null;

        try {
            const loadingMessage = await interaction.reply({
                content: 'Loading... Please wait a moment.',
                ephemeral: true,
            });

            const response = await exports["fd-clockin"].getHours(false, filter, formattedDate);

            const embed = new EmbedBuilder()
                .setColor(0x00FF00)
                .setTitle('Leaderboard')
                .setDescription(`Here is a leaderboard based on the filter: **${filter}**\n\n${response}`)
                .setFooter({ text: 'Requested by ' + interaction.member.displayName, iconURL: interaction.user.avatarURL() })
                .setTimestamp();

            await loadingMessage.edit({
                content: null,
                embeds: [embed],
            });

        } catch (error) {
            console.error('Error fetching hours:', error);
            await interaction.reply({
                content: 'An error occurred while fetching the hours. Please try again later.',
                ephemeral: true,
            });
        }
    }
});

module.exports = client;

client.login(token);